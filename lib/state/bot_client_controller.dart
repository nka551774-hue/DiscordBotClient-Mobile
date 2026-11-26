import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/discord_models.dart';
import '../services/discord_gateway_service.dart';
import '../services/discord_rest_client.dart';

class BotClientController extends ChangeNotifier with WidgetsBindingObserver {
  static const String _kAccountsKey = 'dbc_saved_accounts_v1';
  static const String _kActiveAccountIdKey = 'dbc_active_account_id_v1';
  static const String _kEcoSettingsKey = 'dbc_eco_settings_v1';
  static const String _kDmChannelsPrefix = 'dbc_dm_channels_';

  SharedPreferences? _prefs;
  DiscordRestClient? _rest;
  DiscordGatewayService? _gateway;

  EcoSettings _ecoSettings = const EcoSettings();
  EcoSettings get ecoSettings => _ecoSettings;

  final List<BotAccount> _savedAccounts = <BotAccount>[];
  List<BotAccount> get savedAccounts => List.unmodifiable(_savedAccounts);

  BotAccount? _activeAccount;
  BotAccount? get activeAccount => _activeAccount;

  bool _initializing = true;
  bool get initializing => _initializing;

  bool _authenticating = false;
  bool get authenticating => _authenticating;

  String? _authError;
  String? get authError => _authError;

  bool _disallowedIntentsBanner = false;
  bool get disallowedIntentsBanner => _disallowedIntentsBanner;

  GatewayConnectionState _gatewayState = GatewayConnectionState.disconnected;
  GatewayConnectionState get gatewayState => _gatewayState;

  // Granular ValueNotifiers so high-frequency events never rebuild the whole UI tree!
  final ValueNotifier<int?> pingMsNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int> gatewayEventsCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<DiscordMessage>> messagesNotifier =
      ValueNotifier<List<DiscordMessage>>(const []);
  final ValueNotifier<bool> loadingMessagesNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<String?> typingBannerNotifier =
      ValueNotifier<String?>(null);

  // Guilds & Local Persistent DM Channels
  final LinkedHashMap<String, DiscordGuild> _guilds =
      LinkedHashMap<String, DiscordGuild>();
  List<DiscordGuild> get guilds => _guilds.values.toList(growable: false);

  final LinkedHashMap<String, DiscordChannel> _dmChannels =
      LinkedHashMap<String, DiscordChannel>();
  List<DiscordChannel> get dmChannels =>
      _dmChannels.values.toList(growable: false);

  final Set<String> _unreadChannelIds = <String>{};
  Set<String> get unreadChannelIds => _unreadChannelIds;

  final Set<String> _collapsedCategoryIds = <String>{};
  bool isCategoryCollapsed(String categoryId) =>
      _collapsedCategoryIds.contains(categoryId);

  String? _selectedGuildId; // null => Direct Messages view
  String? get selectedGuildId => _selectedGuildId;
  DiscordGuild? get selectedGuild =>
      _selectedGuildId != null ? _guilds[_selectedGuildId] : null;

  String? _selectedChannelId;
  String? get selectedChannelId => _selectedChannelId;

  DiscordChannel? get selectedChannel {
    if (_selectedChannelId == null) return null;
    if (_selectedGuildId == null) {
      return _dmChannels[_selectedChannelId];
    }
    final guild = _guilds[_selectedGuildId];
    if (guild == null) return null;
    for (final ch in guild.channels) {
      if (ch.id == _selectedChannelId) return ch;
    }
    return null;
  }

  // Bounded LRU cache of messages per channel (max 15 channels * 150 msgs)
  final LinkedHashMap<String, List<DiscordMessage>> _messageCache =
      LinkedHashMap<String, List<DiscordMessage>>();
  bool _loadingOlderMessages = false;
  bool get loadingOlderMessages => _loadingOlderMessages;

  // Bot Presence state
  String _botStatus = 'online';
  String get botStatus => _botStatus;
  int _botActivityType = 0;
  int get botActivityType => _botActivityType;
  String _botActivityName = '';
  String get botActivityName => _botActivityName;

  Timer? _ecoSuspendTimer;
  Timer? _typingClearTimer;
  Timer? _coalesceNotifyTimer;
  DateTime _lastTypingTriggerSent = DateTime.fromMillisecondsSinceEpoch(0);

  DiscordRestClient? get rest => _rest;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _prefs = await SharedPreferences.getInstance();

    final ecoRaw = _prefs?.getString(_kEcoSettingsKey);
    if (ecoRaw != null) {
      try {
        _ecoSettings =
            EcoSettings.fromJson(jsonDecode(ecoRaw) as Map<String, dynamic>);
      } catch (_) {}
    }
    _applyImageCacheLimits();

    final accountsRaw = _prefs?.getString(_kAccountsKey);
    if (accountsRaw != null) {
      try {
        final list = jsonDecode(accountsRaw) as List<dynamic>;
        _savedAccounts
          ..clear()
          ..addAll(
              list.whereType<Map<String, dynamic>>().map(BotAccount.fromJson));
      } catch (_) {}
    }

    final lastActiveId = _prefs?.getString(_kActiveAccountIdKey);
    if (lastActiveId != null && _savedAccounts.isNotEmpty) {
      BotAccount? target;
      for (final acc in _savedAccounts) {
        if (acc.id == lastActiveId) {
          target = acc;
          break;
        }
      }
      if (target != null) {
        _initializing = false;
        notifyListeners();
        await loginWithToken(target.token, silentAccountSwitch: true);
        return;
      }
    }

    _initializing = false;
    notifyListeners();
  }

  void _applyImageCacheLimits() {
    final cache = PaintingBinding.instance.imageCache;
    if (_ecoSettings.ecoPowerSaving) {
      cache.maximumSize = 120;
      cache.maximumSizeBytes = 35 << 20; // 35 MB cap
    } else {
      cache.maximumSize = 300;
      cache.maximumSizeBytes = 80 << 20; // 80 MB cap
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_gateway == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_ecoSettings.ecoPowerSaving) {
        _ecoSuspendTimer?.cancel();
        _ecoSuspendTimer = Timer(
          Duration(seconds: _ecoSettings.backgroundSuspendSeconds),
          () {
            _gateway?.suspendForBackground();
          },
        );
      }
    } else if (state == AppLifecycleState.resumed) {
      _ecoSuspendTimer?.cancel();
      _gateway?.resumeFromBackground();
    }
  }

  String _sanitizeToken(String raw) {
    var cleaned = raw.trim();
    if (cleaned.startsWith('"') && cleaned.endsWith('"') && cleaned.length > 2) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    if (cleaned.toLowerCase().startsWith('bot ')) {
      cleaned = cleaned.substring(4).trim();
    }
    return cleaned;
  }

  Future<bool> loginWithToken(
    String rawToken, {
    bool silentAccountSwitch = false,
  }) async {
    final token = _sanitizeToken(rawToken);
    if (token.isEmpty) {
      _authError = '請輸入有效的 Discord Bot Token';
      notifyListeners();
      return false;
    }

    _authenticating = true;
    _authError = null;
    _disallowedIntentsBanner = false;
    notifyListeners();

    final candidateRest = DiscordRestClient(token: token);
    try {
      final account = await candidateRest.validateBotToken();

      // Clean up any existing session
      await _teardownSession(clearActivePref: false);

      _rest = candidateRest;
      _activeAccount = account;

      // Save / update in saved accounts list
      _savedAccounts.removeWhere((a) => a.id == account.id);
      _savedAccounts.insert(0, account);
      await _persistAccounts();
      await _prefs?.setString(_kActiveAccountIdKey, account.id);

      // Load local persistent DM channels for this bot (like DiscordBotClient)
      _loadPersistedDmChannels(account.id);

      // Preload guild list via REST so UI populates immediately while Gateway connects
      try {
        final initialGuilds = await candidateRest.getUserGuilds();
        for (final g in initialGuilds) {
          _guilds[g.id] = g;
        }
      } catch (_) {}

      // Start Gateway WebSocket
      _gateway = DiscordGatewayService(
        token: token,
        ecoSettings: _ecoSettings,
        onDispatch: _handleGatewayDispatch,
        onStateChanged: (st) {
          _gatewayState = st;
          _scheduleCoalescedNotify();
        },
        onPingUpdated: (ms) {
          pingMsNotifier.value = ms;
        },
        onFatalError: (err) {
          _authError = err;
          notifyListeners();
        },
        onDisallowedIntentsFallback: () {
          _disallowedIntentsBanner = true;
          notifyListeners();
        },
      );
      unawaited(_gateway!.connect());

      // Auto-select first guild & first messageable channel
      if (_guilds.isNotEmpty) {
        await selectGuild(_guilds.keys.first);
      } else {
        _selectedGuildId = null;
        if (_dmChannels.isNotEmpty) {
          await selectChannel(_dmChannels.keys.first);
        }
      }

      _authenticating = false;
      notifyListeners();
      return true;
    } catch (e) {
      candidateRest.dispose();
      _authenticating = false;
      _authError = e is DiscordApiException
          ? e.message
          : '連線至 Discord 失敗，請確認網路狀態與 Bot Token 是否正確。';
      notifyListeners();
      return false;
    }
  }

  Future<void> logoutCurrentAccount() async {
    await _teardownSession(clearActivePref: true);
    notifyListeners();
  }

  Future<void> removeSavedAccount(String accountId) async {
    _savedAccounts.removeWhere((a) => a.id == accountId);
    await _persistAccounts();
    if (_activeAccount?.id == accountId) {
      await logoutCurrentAccount();
    } else {
      notifyListeners();
    }
  }

  Future<void> _teardownSession({required bool clearActivePref}) async {
    _ecoSuspendTimer?.cancel();
    _typingClearTimer?.cancel();
    _coalesceNotifyTimer?.cancel();
    await _gateway?.dispose();
    _gateway = null;
    _rest?.dispose();
    _rest = null;

    _activeAccount = null;
    _guilds.clear();
    _dmChannels.clear();
    _messageCache.clear();
    _unreadChannelIds.clear();
    _selectedGuildId = null;
    _selectedChannelId = null;
    _gatewayState = GatewayConnectionState.disconnected;
    pingMsNotifier.value = null;
    gatewayEventsCountNotifier.value = 0;
    messagesNotifier.value = const [];
    typingBannerNotifier.value = null;

    if (clearActivePref) {
      await _prefs?.remove(_kActiveAccountIdKey);
    }
  }

  Future<void> _persistAccounts() async {
    final encoded =
        jsonEncode(_savedAccounts.map((e) => e.toJson()).toList());
    await _prefs?.setString(_kAccountsKey, encoded);
  }

  void _loadPersistedDmChannels(String botId) {
    _dmChannels.clear();
    final raw = _prefs?.getString('$_kDmChannelsPrefix$botId');
    if (raw == null) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      for (final item in list) {
        if (item is Map<String, dynamic>) {
          final ch = DiscordChannel.fromJson(item);
          _dmChannels[ch.id] = ch;
        }
      }
    } catch (_) {}
  }

  Future<void> _savePersistedDmChannels() async {
    final botId = _activeAccount?.id;
    if (botId == null) return;
    final list = _dmChannels.values.take(80).map((c) => c.toJson()).toList();
    await _prefs?.setString('$_kDmChannelsPrefix$botId', jsonEncode(list));
  }

  void dismissIntentsBanner() {
    _disallowedIntentsBanner = false;
    notifyListeners();
  }

  void toggleCategoryCollapse(String categoryId) {
    if (_collapsedCategoryIds.contains(categoryId)) {
      _collapsedCategoryIds.remove(categoryId);
    } else {
      _collapsedCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  Future<void> selectDmMode() async {
    _selectedGuildId = null;
    if (_dmChannels.isNotEmpty) {
      final firstId = _dmChannels.keys.first;
      await selectChannel(firstId);
    } else {
      _selectedChannelId = null;
      messagesNotifier.value = const [];
      notifyListeners();
    }
  }

  Future<void> selectGuild(String guildId) async {
    _selectedGuildId = guildId;
    var guild = _guilds[guildId];
    if (guild == null) return;

    notifyListeners();

    if (!guild.channelsLoaded && _rest != null && _activeAccount != null) {
      try {
        guild = await _rest!.getGuildDetails(
          guildId,
          botUserId: _activeAccount!.id,
        );
        _guilds[guildId] = guild;
        notifyListeners();
      } catch (_) {}
    }

    final resolvedGuild = guild!;
    // Pick first viewable text channel sorted by position
    final candidates = resolvedGuild.channels
        .where((c) => c.isMessageable && canViewChannel(resolvedGuild, c))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    if (candidates.isNotEmpty) {
      // Prefer type == 0 (standard text channel) first
      final textCh = candidates.firstWhere(
        (c) => c.type == 0,
        orElse: () => candidates.first,
      );
      await selectChannel(textCh.id);
    } else {
      _selectedChannelId = null;
      messagesNotifier.value = const [];
      notifyListeners();
    }
  }

  bool canViewChannel(DiscordGuild guild, DiscordChannel channel) {
    if (_activeAccount == null) return true;
    if (guild.roles.isEmpty) return true;
    final perms = DiscordPermissions.computeChannelPermissions(
      guild: guild,
      channel: channel,
      botUserId: _activeAccount!.id,
      botRoleIds: guild.botRoleIds,
    );
    return DiscordPermissions.has(perms, DiscordPermissions.viewChannel);
  }

  bool canSendInSelectedChannel() {
    final ch = selectedChannel;
    if (ch == null) return false;
    if (ch.isDm) return true;
    final guild = selectedGuild;
    if (guild == null || _activeAccount == null || guild.roles.isEmpty) {
      return true;
    }
    final perms = DiscordPermissions.computeChannelPermissions(
      guild: guild,
      channel: ch,
      botUserId: _activeAccount!.id,
      botRoleIds: guild.botRoleIds,
    );
    return DiscordPermissions.has(perms, DiscordPermissions.sendMessages);
  }

  BigInt currentChannelPermissions() {
    final ch = selectedChannel;
    final guild = selectedGuild;
    if (ch == null ||
        ch.isDm ||
        guild == null ||
        _activeAccount == null ||
        guild.roles.isEmpty) {
      return DiscordPermissions.all;
    }
    return DiscordPermissions.computeChannelPermissions(
      guild: guild,
      channel: ch,
      botUserId: _activeAccount!.id,
      botRoleIds: guild.botRoleIds,
    );
  }

  Future<void> selectChannel(String channelId) async {
    _selectedChannelId = channelId;
    _unreadChannelIds.remove(channelId);
    typingBannerNotifier.value = null;
    notifyListeners();

    final cached = _messageCache[channelId];
    if (cached != null) {
      // Refresh LRU order
      _messageCache.remove(channelId);
      _messageCache[channelId] = cached;
      messagesNotifier.value = List.unmodifiable(cached);
      return;
    }

    if (_rest == null) return;
    loadingMessagesNotifier.value = true;
    messagesNotifier.value = const [];

    try {
      final fetched = await _rest!.getChannelMessages(channelId, limit: 50);
      _putChannelCache(channelId, fetched);
      if (_selectedChannelId == channelId) {
        messagesNotifier.value = List.unmodifiable(fetched);
      }
    } catch (_) {
      if (_selectedChannelId == channelId) {
        messagesNotifier.value = const [];
      }
    } finally {
      if (_selectedChannelId == channelId) {
        loadingMessagesNotifier.value = false;
      }
    }
  }

  Future<void> loadOlderMessages() async {
    final chId = _selectedChannelId;
    if (chId == null || _rest == null || _loadingOlderMessages) return;
    final current = _messageCache[chId];
    if (current == null || current.isEmpty) return;

    _loadingOlderMessages = true;
    final oldestId = current.last.id;
    try {
      final older = await _rest!.getChannelMessages(
        chId,
        before: oldestId,
        limit: 50,
      );
      if (older.isNotEmpty) {
        final existingIds = current.map((m) => m.id).toSet();
        final merged = <DiscordMessage>[
          ...current,
          ...older.where((m) => !existingIds.contains(m.id)),
        ];
        // Cap in-memory history to 200 messages in Eco mode to keep RAM flat
        final maxKeep = _ecoSettings.ecoPowerSaving ? 180 : 350;
        final trimmed =
            merged.length > maxKeep ? merged.sublist(0, maxKeep) : merged;
        _putChannelCache(chId, trimmed);
        if (_selectedChannelId == chId) {
          messagesNotifier.value = List.unmodifiable(trimmed);
        }
      }
    } catch (_) {
    } finally {
      _loadingOlderMessages = false;
    }
  }

  Future<void> refreshCurrentChannel() async {
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) return;
    _messageCache.remove(chId);
    await selectChannel(chId);
  }

  void _putChannelCache(String channelId, List<DiscordMessage> messages) {
    _messageCache.remove(channelId);
    _messageCache[channelId] = messages;
    final maxChannels = _ecoSettings.ecoPowerSaving ? 12 : 25;
    while (_messageCache.length > maxChannels) {
      _messageCache.remove(_messageCache.keys.first);
    }
  }

  Future<DiscordMessage> sendChatMessage({
    String content = '',
    String? replyToMessageId,
    List<DiscordEmbed>? embeds,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) {
      throw const DiscordApiException(400, '尚未選擇頻道');
    }
    final sent = await _rest!.sendMessage(
      chId,
      content: content,
      replyToMessageId: replyToMessageId,
      embeds: embeds,
      fileBytes: fileBytes,
      fileName: fileName,
    );
    _insertOrUpdateMessage(chId, sent, isNew: true);
    return sent;
  }

  Future<void> editChatMessage(String messageId, String newContent) async {
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) return;
    final updated = await _rest!.editMessage(chId, messageId, content: newContent);
    _insertOrUpdateMessage(chId, updated, isNew: false);
  }

  Future<void> deleteChatMessage(String messageId) async {
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) return;
    await _rest!.deleteMessage(chId, messageId);
    _removeMessageFromCache(chId, messageId);
  }

  Future<void> toggleReaction(
    DiscordMessage message,
    DiscordEmoji emoji,
    bool currentlyReactedByMe,
  ) async {
    if (_rest == null) return;
    final idStr = emoji.apiIdentifier;
    if (currentlyReactedByMe) {
      await _rest!.removeOwnReaction(message.channelId, message.id, idStr);
    } else {
      await _rest!.addReaction(message.channelId, message.id, idStr);
    }
    // Optimistically update local reaction count for instant smoothness
    final rxns = List<DiscordReaction>.from(message.reactions);
    final idx = rxns.indexWhere((r) => r.emoji.apiIdentifier == idStr);
    if (currentlyReactedByMe) {
      if (idx != -1) {
        final nextCount = rxns[idx].count - 1;
        if (nextCount <= 0) {
          rxns.removeAt(idx);
        } else {
          rxns[idx] = rxns[idx].copyWith(count: nextCount, me: false);
        }
      }
    } else {
      if (idx != -1) {
        rxns[idx] = rxns[idx].copyWith(count: rxns[idx].count + 1, me: true);
      } else {
        rxns.add(DiscordReaction(emoji: emoji, count: 1, me: true));
      }
    }
    _insertOrUpdateMessage(
      message.channelId,
      message.copyWith(reactions: rxns),
      isNew: false,
    );
  }

  void notifyUserTyping() {
    if (_ecoSettings.silentTyping || _ecoSettings.ecoPowerSaving) return;
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingTriggerSent).inSeconds >= 8) {
      _lastTypingTriggerSent = now;
      unawaited(_rest!.triggerTyping(chId).catchError((_) {}));
    }
  }

  Future<DiscordChannel> openDmWithUser(String userId) async {
    if (_rest == null) {
      throw const DiscordApiException(400, '尚未登入');
    }
    final dm = await _rest!.createDirectMessage(userId);
    _dmChannels.remove(dm.id);
    // Insert at top of DM map
    final existing = Map<String, DiscordChannel>.from(_dmChannels);
    _dmChannels
      ..clear()
      ..[dm.id] = dm
      ..addAll(existing);
    await _savePersistedDmChannels();
    _selectedGuildId = null;
    await selectChannel(dm.id);
    return dm;
  }

  void updateBotPresence({
    required String status,
    required int activityType,
    required String activityName,
  }) {
    _botStatus = status;
    _botActivityType = activityType;
    _botActivityName = activityName;
    _gateway?.updatePresence(
      status: status,
      activityType: activityType,
      activityName: activityName,
    );
    notifyListeners();
  }

  Future<void> updateEcoSettings(
    EcoSettings nextSettings, {
    bool reconnectGateway = false,
  }) async {
    _ecoSettings = nextSettings;
    _applyImageCacheLimits();
    await _prefs?.setString(_kEcoSettingsKey, jsonEncode(nextSettings.toJson()));
    await _gateway?.updateEcoSettings(nextSettings, reconnect: reconnectGateway);
    notifyListeners();
  }

  void clearMemoryCaches() {
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    final activeCh = _selectedChannelId;
    final keep = activeCh != null ? _messageCache[activeCh] : null;
    _messageCache.clear();
    if (activeCh != null && keep != null) {
      _messageCache[activeCh] = keep;
    }
    notifyListeners();
  }

  // ==========================================================
  // Gateway Real-Time Event Handling (Micro-batched for 120fps)
  // ==========================================================
  void _handleGatewayDispatch(GatewayDispatchEvent event) {
    gatewayEventsCountNotifier.value = gatewayEventsCountNotifier.value + 1;
    final data = event.data;

    switch (event.type) {
      case 'GUILD_CREATE':
        if (data is Map<String, dynamic>) {
          final parsed = DiscordGuild.fromJson(
            data,
            currentBotUserId: _activeAccount?.id,
          );
          _guilds[parsed.id] = parsed;
          if (_selectedGuildId == null && _dmChannels.isEmpty) {
            unawaited(selectGuild(parsed.id));
          } else if (_selectedGuildId == parsed.id &&
              _selectedChannelId == null) {
            unawaited(selectGuild(parsed.id));
          } else {
            _scheduleCoalescedNotify();
          }
        }
        break;

      case 'GUILD_UPDATE':
        if (data is Map<String, dynamic>) {
          final id = data['id']?.toString();
          if (id != null && _guilds.containsKey(id)) {
            final prev = _guilds[id]!;
            final updated = DiscordGuild.fromJson(data);
            _guilds[id] = prev.copyWith(
              name: updated.name,
              icon: updated.icon,
              ownerId: updated.ownerId,
              roles: updated.roles.isNotEmpty ? updated.roles : prev.roles,
              emojis: updated.emojis.isNotEmpty ? updated.emojis : prev.emojis,
            );
            _scheduleCoalescedNotify();
          }
        }
        break;

      case 'GUILD_DELETE':
        if (data is Map<String, dynamic>) {
          final id = data['id']?.toString();
          if (id != null && data['unavailable'] != true) {
            _guilds.remove(id);
            if (_selectedGuildId == id) {
              _selectedGuildId = _guilds.isNotEmpty ? _guilds.keys.first : null;
              _selectedChannelId = null;
              messagesNotifier.value = const [];
            }
            _scheduleCoalescedNotify();
          }
        }
        break;

      case 'CHANNEL_CREATE':
      case 'CHANNEL_UPDATE':
        if (data is Map<String, dynamic>) {
          final ch = DiscordChannel.fromJson(data);
          if (ch.isDm) {
            _dmChannels[ch.id] = ch;
            unawaited(_savePersistedDmChannels());
          } else if (ch.guildId != null && _guilds.containsKey(ch.guildId)) {
            final g = _guilds[ch.guildId]!;
            final list = List<DiscordChannel>.from(g.channels);
            final idx = list.indexWhere((c) => c.id == ch.id);
            if (idx >= 0) {
              list[idx] = ch;
            } else {
              list.add(ch);
            }
            _guilds[g.id] = g.copyWith(channels: list);
          }
          _scheduleCoalescedNotify();
        }
        break;

      case 'CHANNEL_DELETE':
        if (data is Map<String, dynamic>) {
          final chId = data['id']?.toString();
          final gId = data['guild_id']?.toString();
          if (chId != null) {
            _dmChannels.remove(chId);
            if (gId != null && _guilds.containsKey(gId)) {
              final g = _guilds[gId]!;
              _guilds[gId] = g.copyWith(
                channels: g.channels.where((c) => c.id != chId).toList(),
              );
            }
            if (_selectedChannelId == chId) {
              _selectedChannelId = null;
              messagesNotifier.value = const [];
            }
            _scheduleCoalescedNotify();
          }
        }
        break;

      case 'MESSAGE_CREATE':
        if (data is Map<String, dynamic>) {
          final msg = DiscordMessage.fromJson(data);
          // Auto-capture incoming Direct Messages into persistent local DM store!
          if (msg.guildId == null && msg.author.id != _activeAccount?.id) {
            if (!_dmChannels.containsKey(msg.channelId)) {
              _dmChannels[msg.channelId] = DiscordChannel(
                id: msg.channelId,
                name: msg.author.displayName,
                type: 1,
                lastMessageId: msg.id,
                recipients: [msg.author],
              );
              unawaited(_savePersistedDmChannels());
              _scheduleCoalescedNotify();
            }
          }
          _insertOrUpdateMessage(msg.channelId, msg, isNew: true);
          if (msg.channelId != _selectedChannelId &&
              msg.author.id != _activeAccount?.id) {
            _unreadChannelIds.add(msg.channelId);
            _scheduleCoalescedNotify();
          } else if (msg.channelId == _selectedChannelId) {
            typingBannerNotifier.value = null;
          }
        }
        break;

      case 'MESSAGE_UPDATE':
        if (data is Map<String, dynamic>) {
          final chId = data['channel_id']?.toString();
          final msgId = data['id']?.toString();
          if (chId != null && msgId != null && _messageCache.containsKey(chId)) {
            final list = _messageCache[chId]!;
            final idx = list.indexWhere((m) => m.id == msgId);
            if (idx != -1) {
              final existing = list[idx];
              final updated = existing.copyWith(
                content: data['content'] as String? ?? existing.content,
                editedTimestamp: data['edited_timestamp'] != null
                    ? DateTime.tryParse(data['edited_timestamp'] as String)
                        ?.toLocal()
                    : existing.editedTimestamp,
                pinned: data['pinned'] as bool? ?? existing.pinned,
                embeds: data['embeds'] is List<dynamic>
                    ? (data['embeds'] as List<dynamic>)
                        .whereType<Map<String, dynamic>>()
                        .map(DiscordEmbed.fromJson)
                        .toList()
                    : existing.embeds,
              );
              _insertOrUpdateMessage(chId, updated, isNew: false);
            }
          }
        }
        break;

      case 'MESSAGE_DELETE':
        if (data is Map<String, dynamic>) {
          final chId = data['channel_id']?.toString();
          final msgId = data['id']?.toString();
          if (chId != null && msgId != null) {
            _removeMessageFromCache(chId, msgId);
          }
        }
        break;

      case 'MESSAGE_DELETE_BULK':
        if (data is Map<String, dynamic>) {
          final chId = data['channel_id']?.toString();
          final ids = (data['ids'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toSet();
          if (chId != null && _messageCache.containsKey(chId)) {
            final next = _messageCache[chId]!
                .where((m) => !ids.contains(m.id))
                .toList();
            _messageCache[chId] = next;
            if (_selectedChannelId == chId) {
              messagesNotifier.value = List.unmodifiable(next);
            }
          }
        }
        break;

      case 'TYPING_START':
        if (data is Map<String, dynamic>) {
          final chId = data['channel_id']?.toString();
          if (chId == _selectedChannelId) {
            final member = data['member'] as Map<String, dynamic>?;
            final user = member?['user'] as Map<String, dynamic>?;
            final userId = data['user_id']?.toString();
            if (userId != _activeAccount?.id) {
              final name = member?['nick'] as String? ??
                  user?['global_name'] as String? ??
                  user?['username'] as String? ??
                  '有人';
              typingBannerNotifier.value = '$name 正在輸入...';
              _typingClearTimer?.cancel();
              _typingClearTimer = Timer(const Duration(seconds: 7), () {
                typingBannerNotifier.value = null;
              });
            }
          }
        }
        break;
    }
  }

  void _insertOrUpdateMessage(
    String channelId,
    DiscordMessage msg, {
    required bool isNew,
  }) {
    final existing = _messageCache[channelId];
    if (existing == null) {
      if (channelId == _selectedChannelId) {
        _putChannelCache(channelId, [msg]);
        messagesNotifier.value = List.unmodifiable([msg]);
      }
      return;
    }

    final list = List<DiscordMessage>.from(existing);
    final idx = list.indexWhere((m) => m.id == msg.id);
    if (idx >= 0) {
      list[idx] = msg;
    } else if (isNew) {
      list.insert(0, msg); // Newest at index 0 for reverse: true ListView
      final maxKeep = _ecoSettings.ecoPowerSaving ? 150 : 300;
      if (list.length > maxKeep) {
        list.removeRange(maxKeep, list.length);
      }
    }
    _messageCache[channelId] = list;
    if (_selectedChannelId == channelId) {
      messagesNotifier.value = List.unmodifiable(list);
    }
  }

  void _removeMessageFromCache(String channelId, String messageId) {
    final existing = _messageCache[channelId];
    if (existing == null) return;
    final next = existing.where((m) => m.id != messageId).toList();
    _messageCache[channelId] = next;
    if (_selectedChannelId == channelId) {
      messagesNotifier.value = List.unmodifiable(next);
    }
  }

  /// Coalesces structural UI notifications within a 16ms frame budget so burst
  /// Gateway events (like initial GUILD_CREATE flood) never drop frames!
  void _scheduleCoalescedNotify() {
    if (_coalesceNotifyTimer?.isActive ?? false) return;
    _coalesceNotifyTimer = Timer(const Duration(milliseconds: 16), () {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _teardownSession(clearActivePref: false);
    pingMsNotifier.dispose();
    gatewayEventsCountNotifier.dispose();
    messagesNotifier.dispose();
    loadingMessagesNotifier.dispose();
    typingBannerNotifier.dispose();
    super.dispose();
  }
}
