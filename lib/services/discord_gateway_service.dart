import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data' as td;

import '../models/discord_models.dart';

enum GatewayConnectionState {
  disconnected,
  connecting,
  connected,
  suspendedEco,
}

class GatewayDispatchEvent {
  final String type;
  final dynamic data;

  const GatewayDispatchEvent(this.type, this.data);
}

class _BytesCollectorSink implements Sink<List<int>> {
  final void Function(List<int> chunk) onChunk;
  _BytesCollectorSink(this.onChunk);

  @override
  void add(List<int> data) => onChunk(data);

  @override
  void close() {}
}

class DiscordGatewayService {
  static const String _defaultGatewayUrl = 'wss://gateway.discord.gg';

  final String token;
  final int applicationFlags;
  int currentShard;
  int totalShards;
  EcoSettings ecoSettings;
  final void Function(GatewayDispatchEvent event) onDispatch;
  final void Function(GatewayConnectionState state) onStateChanged;
  final void Function(int? pingMs) onPingUpdated;
  final void Function(String fatalError) onFatalError;
  final void Function() onDisallowedIntentsFallback;

  WebSocket? _socket;
  StreamSubscription<dynamic>? _socketSub;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  String? _sessionId;
  String? _resumeGatewayUrl;
  int? _lastSequence;

  bool _disposed = false;
  bool _suspendedForEco = false;
  bool _stripPrivilegedIntents = false;
  bool _useZlibStream = true;
  bool _awaitingAck = false;
  DateTime? _lastHeartbeatSentAt;
  int _reconnectAttempts = 0;

  // Zlib stream state
  // td.BytesBuilder: List<int> would store 8 bytes per byte and copy on addAll.
  final td.BytesBuilder _compressedFrameBuffer = td.BytesBuilder(copy: false);
  final td.BytesBuilder _inflatedBuffer = td.BytesBuilder(copy: false);
  // Packets are handled strictly in arrival order; big ones decode off-thread.
  Future<void> _packetQueue = Future<void>.value();
  int _connectionGen = 0;
  static const int _offThreadBytes = 256 * 1024;
  ByteConversionSink? _zlibSink;

  GatewayConnectionState _state = GatewayConnectionState.disconnected;
  GatewayConnectionState get state => _state;

  String _currentStatus = 'online';
  int _currentActivityType = 4;
  String _currentActivityName = '';

  DiscordGatewayService({
    required this.token,
    this.applicationFlags = 0,
    this.currentShard = 0,
    this.totalShards = 1,
    required this.ecoSettings,
    required this.onDispatch,
    required this.onStateChanged,
    required this.onPingUpdated,
    required this.onFatalError,
    required this.onDisallowedIntentsFallback,
  });

  void _setState(GatewayConnectionState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged(next);
  }

  Future<void> connect() async {
    if (_disposed) return;
    _suspendedForEco = false;
    _reconnectTimer?.cancel();
    await _closeCurrentSocket();

    _setState(GatewayConnectionState.connecting);
    _initZlibStream();

    final base = (_resumeGatewayUrl != null && _resumeGatewayUrl!.isNotEmpty)
        ? _resumeGatewayUrl!
        : _defaultGatewayUrl;
    final cleanBase = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
    final query = _useZlibStream
        ? '?v=10&encoding=json&compress=zlib-stream'
        : '?v=10&encoding=json';

    try {
      _socket = await WebSocket.connect('$cleanBase/$query')
          .timeout(const Duration(seconds: 15));
      _socket!.pingInterval = const Duration(seconds: 45);

      _socketSub = _socket!.listen(
        _onRawFrame,
        onError: (_) => _scheduleReconnect(),
        onDone: _onSocketClosed,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _initZlibStream() {
    _connectionGen++;
    _compressedFrameBuffer.clear();
    _inflatedBuffer.clear();
    _zlibSink?.close();
    _zlibSink = null;
    if (_useZlibStream) {
      _zlibSink = zlib.decoder.startChunkedConversion(
        _BytesCollectorSink((chunk) {
          _inflatedBuffer.add(chunk);
        }),
      );
    }
  }

  void _onRawFrame(dynamic frame) {
    if (_disposed) return;

    if (frame is String) {
      _enqueuePacket(frame);
      return;
    }

    if (frame is List<int>) {
      if (!_useZlibStream) {
        _enqueuePacket(
            frame is td.Uint8List ? frame : td.Uint8List.fromList(frame));
        return;
      }

      _compressedFrameBuffer.add(frame);
      // The zlib flush suffix ends the last frame of a message.
      final tail = frame.length >= 4 ? frame : _compressedFrameBuffer.toBytes();
      final n = tail.length;
      final hasZlibFlushSuffix = n >= 4 &&
          tail[n - 4] == 0x00 &&
          tail[n - 3] == 0x00 &&
          tail[n - 2] == 0xFF &&
          tail[n - 1] == 0xFF;

      if (!hasZlibFlushSuffix) return;

      try {
        _zlibSink!.add(_compressedFrameBuffer.takeBytes());

        if (_inflatedBuffer.isEmpty) {
          // Some platform zlib wrappers buffer until stream close; fallback cleanly to plain JSON
          _useZlibStream = false;
          connect();
          return;
        }

        _enqueuePacket(_inflatedBuffer.takeBytes());
      } catch (_) {
        // Fallback to uncompressed JSON mode seamlessly
        _useZlibStream = false;
        connect();
      }
    }
  }

  /// [payload] is a JSON String or UTF-8 bytes. Large payloads (GUILD_CREATE,
  /// READY) are decoded in a background isolate so the UI never stutters.
  void _enqueuePacket(Object payload) {
    final gen = _connectionGen;
    final size =
        payload is String ? payload.length : (payload as td.Uint8List).length;
    _packetQueue = _packetQueue.then((_) async {
      Map<String, dynamic> packet;
      try {
        if (size > _offThreadBytes) {
          try {
            packet = await _decodeOffThread(payload);
          } catch (_) {
            packet = _decodePacket(payload);
          }
        } else {
          packet = _decodePacket(payload);
        }
      } catch (_) {
        return;
      }
      // Drop packets from a socket that has since been replaced.
      if (_disposed || gen != _connectionGen) return;
      _handlePacket(packet);
    });
  }

  static Map<String, dynamic> _decodePacket(Object payload) =>
      jsonDecode(payload is String ? payload : utf8.decode(payload as td.Uint8List))
          as Map<String, dynamic>;

  // Static so the isolate closure captures only [payload], never `this`.
  static Future<Map<String, dynamic>> _decodeOffThread(Object payload) =>
      Isolate.run(() => _decodePacket(payload));

  void _handlePacket(Map<String, dynamic> packet) {

    final int op = packet['op'] as int? ?? -1;
    final int? seq = packet['s'] as int?;
    if (seq != null) {
      _lastSequence = seq;
    }

    switch (op) {
      case 10: // HELLO
        final d = packet['d'] as Map<String, dynamic>? ?? const {};
        final intervalMs = d['heartbeat_interval'] as int? ?? 41250;
        _startHeartbeating(intervalMs);
        if (_sessionId != null && _lastSequence != null) {
          _sendResume();
        } else {
          _sendIdentify();
        }
        break;

      case 11: // HEARTBEAT_ACK
        _awaitingAck = false;
        if (_lastHeartbeatSentAt != null) {
          final rtt =
              DateTime.now().difference(_lastHeartbeatSentAt!).inMilliseconds;
          onPingUpdated(rtt);
        }
        break;

      case 1: // HEARTBEAT requested immediately
        _sendHeartbeat();
        break;

      case 7: // RECONNECT
        _scheduleReconnect(immediate: true);
        break;

      case 9: // INVALID_SESSION
        final canResume = packet['d'] == true;
        if (!canResume) {
          _sessionId = null;
          _lastSequence = null;
          _resumeGatewayUrl = null;
        }
        Future<void>.delayed(
          Duration(milliseconds: 1200 + Random().nextInt(1500)),
          () {
            if (!_disposed && !_suspendedForEco) connect();
          },
        );
        break;

      case 0: // DISPATCH
        final eventType = packet['t'] as String? ?? '';
        final data = packet['d'];
        if (eventType == 'READY' && data is Map<String, dynamic>) {
          _reconnectAttempts = 0;
          _sessionId = data['session_id'] as String?;
          _resumeGatewayUrl = data['resume_gateway_url'] as String?;
          _setState(GatewayConnectionState.connected);
        } else if (eventType == 'RESUMED') {
          _reconnectAttempts = 0;
          _setState(GatewayConnectionState.connected);
        }
        onDispatch(GatewayDispatchEvent(eventType, data));
        break;
    }
  }

  void _startHeartbeating(int intervalMs) {
    _heartbeatTimer?.cancel();
    _awaitingAck = false;

    final firstDelayMs = (intervalMs * (0.25 + Random().nextDouble() * 0.5)).round();
    _heartbeatTimer = Timer(Duration(milliseconds: firstDelayMs), () {
      if (_disposed || _socket == null) return;
      _sendHeartbeat();
      _heartbeatTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        if (_disposed || _socket == null) return;
        if (_awaitingAck) {
          // Zombie connection detected -> reconnect & resume
          _scheduleReconnect(immediate: true);
          return;
        }
        _sendHeartbeat();
      });
    });
  }

  void _sendHeartbeat() {
    if (_socket == null) return;
    _awaitingAck = true;
    _lastHeartbeatSentAt = DateTime.now();
    _sendJson({'op': 1, 'd': _lastSequence});
  }

  void _sendIdentify() {
    final intents = ecoSettings.computeIntentsBitmask(
      applicationFlags: applicationFlags,
      stripPrivileged: _stripPrivilegedIntents,
    );
    _sendJson({
      'op': 2,
      'd': {
        'token': token,
        'intents': intents,
        'shard': [currentShard, totalShards],
        'large_threshold': 100,
        'properties': {
          'os': Platform.isIOS ? 'ios' : 'android',
          'browser': 'Discord Android',
          'device': 'DiscordBotClient',
        },
        'presence': _buildPresencePayload(),
      },
    });
  }

  void _sendResume() {
    _sendJson({
      'op': 6,
      'd': {
        'token': token,
        'session_id': _sessionId,
        'seq': _lastSequence,
      },
    });
  }

  Map<String, dynamic> _buildPresencePayload() {
    final text = _currentActivityName.trim();
    List<Map<String, dynamic>> activities = const [];
    if (text.isNotEmpty) {
      if (_currentActivityType == 4) {
        // Custom Status format from VencordDBCPlugin/utils/patches.ts:
        activities = [
          {
            'name': 'Custom Status',
            'type': 4,
            'state': text,
          }
        ];
      } else {
        activities = [
          {
            'name': text,
            'type': _currentActivityType,
          }
        ];
      }
    }
    return {
      'status': _currentStatus,
      'afk': _currentStatus == 'idle',
      'activities': activities,
      'since': null,
    };
  }

  Future<void> switchShard(int nextShard) async {
    if (nextShard < 0 || nextShard >= totalShards) return;
    currentShard = nextShard;
    _sessionId = null;
    _lastSequence = null;
    _resumeGatewayUrl = null;
    await connect();
  }

  void updatePresence({
    required String status,
    required int activityType,
    required String activityName,
  }) {
    _currentStatus = status;
    _currentActivityType = activityType;
    _currentActivityName = activityName;
    if (_socket != null && _state == GatewayConnectionState.connected) {
      _sendJson({
        'op': 3,
        'd': _buildPresencePayload(),
      });
    }
  }

  void requestGuildMembers(String guildId, {String query = '', int limit = 100}) {
    if (_socket != null && _state == GatewayConnectionState.connected) {
      _sendJson({
        'op': 8,
        'd': {
          'guild_id': guildId,
          'query': query,
          'limit': limit,
        },
      });
    }
  }

  /// Sends Gateway Opcode 4 (Voice State Update) to join, switch, mute/deafen, or leave a voice channel.
  void sendVoiceStateUpdate({
    required String guildId,
    required String? channelId,
    required bool selfMute,
    required bool selfDeaf,
  }) {
    if (_socket != null && _state == GatewayConnectionState.connected) {
      _sendJson({
        'op': 4,
        'd': {
          'guild_id': guildId,
          'channel_id': channelId,
          'self_mute': selfMute,
          'self_deaf': selfDeaf,
        },
      });
    }
  }

  void _sendJson(Map<String, dynamic> data) {
    try {
      _socket?.add(jsonEncode(data));
    } catch (_) {}
  }

  void _onSocketClosed() {
    if (_disposed || _suspendedForEco) return;
    final closeCode = _socket?.closeCode;

    if (closeCode == 4004) {
      _setState(GatewayConnectionState.disconnected);
      onFatalError('Bot Token 驗證失敗 (4004)，請重新檢查您的機器人 Token。');
      return;
    }

    if (closeCode == 4014 && !_stripPrivilegedIntents) {
      // Privileged intents not enabled in Developer Portal -> auto fallback!
      _stripPrivilegedIntents = true;
      _sessionId = null;
      _lastSequence = null;
      onDisallowedIntentsFallback();
      connect();
      return;
    }

    if (closeCode == 4011) {
      _setState(GatewayConnectionState.disconnected);
      onFatalError('此機器人加入超過 2,500 個伺服器 (4011)，需要分片連線。');
      return;
    }

    _scheduleReconnect();
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (_disposed || _suspendedForEco) return;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _setState(GatewayConnectionState.connecting);
    onPingUpdated(null);

    final delayMs = immediate
        ? 300
        : (min(30000, 1000 * (1 << _reconnectAttempts.clamp(0, 5))) +
            Random().nextInt(600));
    _reconnectAttempts++;

    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (!_disposed && !_suspendedForEco) {
        connect();
      }
    });
  }

  /// Suspends the WebSocket completely while app is backgrounded in Eco Mode,
  /// reducing network/CPU battery consumption to 0% until foregrounded.
  Future<void> suspendForBackground() async {
    if (_disposed || _suspendedForEco) return;
    _suspendedForEco = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    onPingUpdated(null);
    await _closeCurrentSocket(closeCode: 1000);
    _setState(GatewayConnectionState.suspendedEco);
  }

  Future<void> resumeFromBackground() async {
    if (_disposed) return;
    if (!_suspendedForEco && _state == GatewayConnectionState.connected) return;
    _suspendedForEco = false;
    await connect();
  }

  Future<void> updateEcoSettings(EcoSettings updated, {bool reconnect = false}) async {
    ecoSettings = updated;
    if (reconnect && !_suspendedForEco && !_disposed) {
      _sessionId = null;
      _lastSequence = null;
      _stripPrivilegedIntents = false;
      await connect();
    }
  }

  Future<void> _closeCurrentSocket({int closeCode = 1000}) async {
    _heartbeatTimer?.cancel();
    await _socketSub?.cancel();
    _socketSub = null;
    try {
      await _socket?.close(closeCode);
    } catch (_) {}
    _socket = null;
    _zlibSink?.close();
    _zlibSink = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    await _closeCurrentSocket();
  }
}
