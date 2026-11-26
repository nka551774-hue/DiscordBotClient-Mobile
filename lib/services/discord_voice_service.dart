import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Connects to Discord's Voice Gateway v8 (`wss://<endpoint>/?v=8`) + UDP IP Discovery
/// to maintain an active Voice session, measure live Voice RTT ping (ms),
/// and stream real-time Opcode 5 SPEAKING events (green speaking ring around avatars!).
class DiscordVoiceService {
  final void Function(String userId, bool speaking) onSpeakingChanged;
  final void Function(int? pingMs) onVoicePingUpdated;
  final void Function(bool connected) onConnectionChanged;

  WebSocket? _ws;
  StreamSubscription<dynamic>? _wsSub;
  RawDatagramSocket? _udp;
  StreamSubscription<RawSocketEvent>? _udpSub;
  Timer? _heartbeatTimer;

  String? _guildId;
  String? _userId;
  String? _sessionId;
  String? _voiceToken;
  String? _endpoint;

  int _lastSeq = -1;
  int? _ssrc;
  String? _serverIp;
  int? _serverPort;
  bool _protocolSelected = false;
  DateTime? _lastHbSent;
  bool _disposed = false;

  final Map<int, String> _ssrcToUserId = <int, String>{};

  DiscordVoiceService({
    required this.onSpeakingChanged,
    required this.onVoicePingUpdated,
    required this.onConnectionChanged,
  });

  Future<void> connect({
    required String guildId,
    required String userId,
    required String sessionId,
    required String voiceToken,
    required String endpoint,
  }) async {
    if (_disposed) return;
    await disconnect(notify: false);

    _guildId = guildId;
    _userId = userId;
    _sessionId = sessionId;
    _voiceToken = voiceToken;
    // Strip :80 or :443 port suffix if present so wss:// uses standard TLS 443 cleanly
    _endpoint = endpoint.replaceFirst(RegExp(r':(80|443)$'), '');
    _lastSeq = -1;
    _protocolSelected = false;
    _ssrcToUserId.clear();

    try {
      _ws = await WebSocket.connect('wss://$_endpoint/?v=8')
          .timeout(const Duration(seconds: 12));
      _wsSub = _ws!.listen(
        _onFrame,
        onError: (_) => onConnectionChanged(false),
        onDone: () => onConnectionChanged(false),
        cancelOnError: true,
      );
    } catch (_) {
      onConnectionChanged(false);
    }
  }

  void _onFrame(dynamic raw) {
    if (_disposed || raw is! String) return;
    Map<String, dynamic> pkt;
    try {
      pkt = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (pkt['seq'] is int) {
      _lastSeq = pkt['seq'] as int;
    }

    final op = pkt['op'] as int? ?? -1;
    final d = pkt['d'];

    switch (op) {
      case 8: // HELLO (Voice Gateway v8)
        if (d is Map<String, dynamic>) {
          final intervalMs =
              (d['heartbeat_interval'] as num?)?.round() ?? 13750;
          _sendIdentify();
          _startHeartbeat(intervalMs);
        }
        break;

      case 2: // READY
        if (d is Map<String, dynamic>) {
          _ssrc = d['ssrc'] as int?;
          _serverIp = d['ip'] as String?;
          _serverPort = d['port'] as int?;
          final modes = (d['modes'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList();
          onConnectionChanged(true);
          // Send an immediate heartbeat once identified so RTT ping populates right away
          _sendHeartbeatFrame();
          if (_ssrc != null && _serverIp != null && _serverPort != null) {
            unawaited(
              _setupUdpDiscovery(_ssrc!, _serverIp!, _serverPort!, modes),
            );
          }
        }
        break;

      case 4: // SESSION_DESCRIPTION
      case 9: // RESUMED
        onConnectionChanged(true);
        break;

      case 5: // SPEAKING
        if (d is Map<String, dynamic>) {
          final ssrc = d['ssrc'] as int?;
          String? uid = d['user_id']?.toString();
          if (uid != null && ssrc != null) {
            _ssrcToUserId[ssrc] = uid;
          } else if (uid == null && ssrc != null) {
            uid = _ssrcToUserId[ssrc];
          }
          if (uid != null) {
            final speakingRaw = d['speaking'];
            final isSpeaking = speakingRaw is int
                ? speakingRaw != 0
                : (speakingRaw == true);
            onSpeakingChanged(uid, isSpeaking);
          }
        }
        break;

      case 6: // HEARTBEAT_ACK
        if (_lastHbSent != null) {
          final rtt = DateTime.now().difference(_lastHbSent!).inMilliseconds;
          onVoicePingUpdated(rtt);
        }
        onConnectionChanged(true);
        break;

      case 13: // CLIENT_DISCONNECT
        if (d is Map<String, dynamic>) {
          final uid = d['user_id']?.toString();
          if (uid != null) {
            onSpeakingChanged(uid, false);
          }
        }
        break;
    }
  }

  void _sendIdentify() {
    _sendJson({
      'op': 0,
      'd': {
        'server_id': _guildId,
        'user_id': _userId,
        'session_id': _sessionId,
        'token': _voiceToken,
        'max_dave_protocol_version': 0,
      },
    });
  }

  void _sendHeartbeatFrame() {
    if (_ws == null || _disposed) return;
    _lastHbSent = DateTime.now();
    // Voice Gateway v8 Heartbeat format requires `t` and `seq_ack`!
    _sendJson({
      'op': 3,
      'd': {
        't': _lastHbSent!.millisecondsSinceEpoch,
        'seq_ack': _lastSeq >= 0 ? _lastSeq : null,
      },
    });
  }

  void _startHeartbeat(int intervalMs) {
    _heartbeatTimer?.cancel();
    final safeMs = intervalMs.clamp(5000, 45000);
    _heartbeatTimer = Timer.periodic(Duration(milliseconds: safeMs), (_) {
      _sendHeartbeatFrame();
    });
  }

  Future<void> _setupUdpDiscovery(
    int ssrc,
    String serverIp,
    int serverPort,
    List<String> availableModes,
  ) async {
    try {
      final targetAddr = InternetAddress.tryParse(serverIp);
      if (targetAddr == null) return;

      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _udpSub = _udp!.listen((event) {
        if (event == RawSocketEvent.read && !_protocolSelected) {
          final dg = _udp?.receive();
          if (dg != null && dg.data.length >= 74) {
            _handleIpDiscoveryResponse(dg.data, availableModes);
          }
        }
      });

      // 74-byte Discord Voice UDP IP Discovery Request:
      // Bytes 0..1 = 0x0001 (Request), Bytes 2..3 = 70 (Length), Bytes 4..7 = SSRC (Big Endian)
      final req = ByteData(74);
      req.setUint16(0, 1, Endian.big);
      req.setUint16(2, 70, Endian.big);
      req.setUint32(4, ssrc, Endian.big);
      _udp!.send(req.buffer.asUint8List(), targetAddr, serverPort);
    } catch (_) {}
  }

  void _handleIpDiscoveryResponse(
    Uint8List data,
    List<String> availableModes,
  ) {
    if (_protocolSelected) return;
    final type = ByteData.sublistView(data).getUint16(0, Endian.big);
    if (type != 2) return;

    int end = 8;
    while (end < 72 && data[end] != 0) {
      end++;
    }
    final discoveredIp = ascii.decode(data.sublist(8, end), allowInvalid: true);
    final discoveredPort =
        ByteData.sublistView(data).getUint16(72, Endian.big);

    String chosenMode = 'aead_xchacha20_poly1305_rtpsize';
    if (!availableModes.contains(chosenMode)) {
      if (availableModes.contains('aead_aes256_gcm_rtpsize')) {
        chosenMode = 'aead_aes256_gcm_rtpsize';
      } else if (availableModes.isNotEmpty) {
        chosenMode = availableModes.first;
      }
    }

    _protocolSelected = true;
    _sendJson({
      'op': 1,
      'd': {
        'protocol': 'udp',
        'data': {
          'address': discoveredIp,
          'port': discoveredPort,
          'mode': chosenMode,
        },
      },
    });
  }

  void _sendJson(Map<String, dynamic> payload) {
    try {
      _ws?.add(jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> disconnect({bool notify = true}) async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _udpSub?.cancel();
    _udpSub = null;
    try {
      _udp?.close();
    } catch (_) {}
    _udp = null;
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _ws?.close(1000);
    } catch (_) {}
    _ws = null;
    _lastSeq = -1;
    _protocolSelected = false;
    _ssrcToUserId.clear();
    onVoicePingUpdated(null);
    if (notify) {
      onConnectionChanged(false);
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    await disconnect(notify: false);
  }
}
