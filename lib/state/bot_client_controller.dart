import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/discord_models.dart';
import '../services/discord_gateway_service.dart';
import '../services/discord_rest_client.dart';
import '../services/discord_voice_service.dart';
import '../services/vencord_engine.dart';

class BotClientController extends ChangeNotifier with WidgetsBindingObserver {
  static const String _kAccountsKey = 'dbc_saved_accounts_v1';
  static const String _kActiveAccountIdKey = 'dbc_active_account_id_v1';
  static const String _kEcoSettingsKey = 'dbc_eco_settings_v1';
  static const String _kDmChannelsPrefix = 'dbc_dm_channels_';
  static const String _kReadStatePrefix = 'dbc_read_state_';
  static const int _guildsPerShard = 1000;

  SharedPreferences? _prefs;
  SharedPreferences? get prefs => _prefs;
  DiscordRestClient? _rest;
  DiscordGatewayService? _gateway;
  DiscordVoiceService? _voiceService;

  late final VencordEngine vencord = VencordEngine(onChanged: _onVencordChanged);

  // Bot Application Emojis (`VencordDBCPlugin/utils/application-emojis.ts`, 5-min TTL)
  List<DiscordEmoji> _applicationEmojis = const [];
  List<DiscordEmoji> get applicationEmojis => _applicationEmojis;
  DateTime _applicationEmojisExpires = DateTime.fromMillisecondsSinceEpoch(0);
  Future<List<DiscordEmoji>>? _pendingAppEmojisFuture;

  void _onVencordChanged() {
    if (!vencord.getSetting<bool>('BotClient', 'saveDirectMessage', true)) {
      final botId = _activeAccount?.id;
      if (botId != null) {
        _prefs?.remove('$_kDmChannelsPrefix$botId');
      }
    }
    notifyListeners();
  }

  // Active Voice Channel state
  String? _activeVoiceGuildId;
  String? get activeVoiceGuildId => _activeVoiceGuildId;
  String? _activeVoiceChannelId;
  String? get activeVoiceChannelId => _activeVoiceChannelId;
  bool _selfMute = false;
  bool get selfMute => _selfMute;
  bool _selfDeaf = false;
  bool get selfDeaf => _selfDeaf;
  bool _voiceStateConfirmed = false;
  bool _voiceGatewayReady = false;
  bool get voiceGatewayReady => _voiceGatewayReady;
  bool get isVoiceConnected => _voiceStateConfirmed || _voiceGatewayReady;
  String? _pendingVoiceSessionId;
  String? _pendingVoiceToken;
  String? _pendingVoiceEndpoint;

  List<SoundboardSound>? _cachedDefaultSounds;
  final Set<String> _loadedSoundboardGuildIds = <String>{};

  final ValueNotifier<int?> voicePingMsNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<Set<String>> speakingUserIdsNotifier =
      ValueNotifier<Set<String>>(const <String>{});

  DiscordChannel? get activeVoiceChannel {
    if (_activeVoiceGuildId == null || _activeVoiceChannelId == null) {
      return null;
    }
    final g = _guilds[_activeVoiceGuildId];
    if (g == null) return null;
    for (final c in g.channels) {
      if (c.id == _activeVoiceChannelId) return c;
    }
    return null;
  }

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

  int get currentShard => _gateway?.currentShard ?? 0;
  int get totalShards => _gateway?.totalShards ?? 1;

  // Granular ValueNotifiers for 120fps isolated rebuilds
  final ValueNotifier<int?> pingMsNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int> gatewayEventsCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<DiscordMessage>> messagesNotifier =
      ValueNotifier<List<DiscordMessage>>(const []);
  final ValueNotifier<bool> loadingMessagesNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<String?> typingBannerNotifier =
      ValueNotifier<String?>(null);

  final LinkedHashMap<String, DiscordGuild> _guilds =
      LinkedHashMap<String, DiscordGuild>();
  List<DiscordGuild> get guilds => _guilds.values.toList(growable: false);

  final LinkedHashMap<String, DiscordChannel> _dmChannels =
      LinkedHashMap<String, DiscordChannel>();
  List<DiscordChannel> get dmChannels {
    final list = _dmChannels.values.toList(growable: false);
    list.sort((a, b) =>
        compareSnowflakes(b.lastMessageId ?? b.id, a.lastMessageId ?? a.id));
    return list;
  }

  // True Read-State tracking: white dot ONLY appears when a newer message arrives!
  final Map<String, String> _lastReadMessageId = <String, String>{};
  final Set<String> _unreadChannelIds = <String>{};
  Set<String> get unreadChannelIds => _unreadChannelIds;

  int _unreadNotificationCount = 0;
  int get unreadNotificationCount => _unreadNotificationCount;

  final List<DiscordMessage> _notifications = <DiscordMessage>[];
  List<DiscordMessage> get notifications => List.unmodifiable(_notifications);

  final Set<String> _collapsedCategoryIds = <String>{};
  bool isCategoryCollapsed(String categoryId) =>
      _collapsedCategoryIds.contains(categoryId);

  String? _selectedGuildId; // null => Direct Messages view
  String? get selectedGuildId => _selectedGuildId;
  String? _lastNonDmGuildId;

  DiscordGuild? get selectedGuild =>
      _selectedGuildId != null ? _guilds[_selectedGuildId] : null;

  String? _selectedChannelId;
  String? get selectedChannelId => _selectedChannelId;

  bool _isActivelyViewingChat = false;
  bool get isActivelyViewingChat => _isActivelyViewingChat;

  void setActivelyViewingChat(bool active) {
    _isActivelyViewingChat = active;
    if (active && _selectedChannelId != null) {
      _markChannelRead(_selectedChannelId!);
    }
  }

  void markNotificationsRead() {
    if (_unreadNotificationCount != 0) {
      _unreadNotificationCount = 0;
      notifyListeners();
    }
  }

  void clearAuthError() {
    if (_authError != null) {
      _authError = null;
      notifyListeners();
    }
  }

  DiscordGuild? findGuildById(String? id) => id != null ? _guilds[id] : null;

  DiscordChannel? findChannelById(String channelId) {
    if (_dmChannels.containsKey(channelId)) return _dmChannels[channelId];
    for (final g in _guilds.values) {
      for (final c in g.channels) {
        if (c.id == channelId) return c;
      }
    }
    return null;
  }

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

  final LinkedHashMap<String, List<DiscordMessage>> _messageCache =
      LinkedHashMap<String, List<DiscordMessage>>();
  final LinkedHashMap<String, DiscordUser> _userProfileCache =
      LinkedHashMap<String, DiscordUser>();
  bool _loadingOlderMessages = false;
  bool get loadingOlderMessages => _loadingOlderMessages;

  // Bot Presence state (default activityType = 4 Custom Status)
  String _botStatus = 'online';
  String get botStatus => _botStatus;
  int _botActivityType = 4;
  int get botActivityType => _botActivityType;
  String _botActivityName = '';
  String get botActivityName => _botActivityName;

  Timer? _ecoSuspendTimer;
  Timer? _typingClearTimer;
  Timer? _coalesceNotifyTimer;
  Timer? _saveReadStateTimer;
  DateTime _lastTypingTriggerSent = DateTime.fromMillisecondsSinceEpoch(0);

  DiscordRestClient? get rest => _rest;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _prefs = await SharedPreferences.getInstance();
    await vencord.load(_prefs);

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
      cache.maximumSizeBytes = 35 << 20;
    } else {
      cache.maximumSize = 300;
      cache.maximumSizeBytes = 80 << 20;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_gateway == null) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // Never suspend Gateway while connected to a Voice Channel!
      if (_ecoSettings.ecoPowerSaving && _activeVoiceChannelId == null) {
        _ecoSuspendTimer?.cancel();
        _ecoSuspendTimer = Timer(
          Duration(seconds: _ecoSettings.backgroundSuspendSeconds),
          () {
            if (_activeVoiceChannelId == null) {
              _gateway?.suspendForBackground();
            }
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
      _authError = 'Token is invalid';
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

      await _teardownSession(clearActivePref: false);

      _rest = candidateRest;
      _activeAccount = account;

      _savedAccounts.removeWhere((a) => a.id == account.id);
      _savedAccounts.insert(0, account);
      await _persistAccounts();
      await _prefs?.setString(_kActiveAccountIdKey, account.id);

      _loadPersistedReadState(account.id);
      if (vencord.getSetting<bool>('BotClient', 'saveDirectMessage', true)) {
        _loadPersistedDmChannels(account.id);
      }
      unawaited(loadApplicationEmojis(force: true));

      try {
        final initialGuilds = await candidateRest.getUserGuilds();
        for (final g in initialGuilds) {
          _guilds[g.id] = g;
        }
      } catch (_) {}

      final computedShards =
          (account.approximateGuildCount / _guildsPerShard).ceil().clamp(1, 64);

      _gateway = DiscordGatewayService(
        token: token,
        applicationFlags: account.applicationFlags,
        currentShard: 0,
        totalShards: computedShards,
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

      if (_guilds.isNotEmpty) {
        await selectGuild(_guilds.keys.first);
      } else {
        _selectedGuildId = null;
        if (_dmChannels.isNotEmpty) {
          await selectChannel(_dmChannels.keys.first, markRead: false);
        }
      }

      _authenticating = false;
      notifyListeners();
      return true;
    } catch (e) {
      candidateRest.dispose();
      _authenticating = false;
      _authError = e is DiscordApiException ? e.message : 'Invalid token';
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
    _saveReadStateTimer?.cancel();
    await _voiceService?.dispose();
    _voiceService = null;
    await _gateway?.dispose();
    _gateway = null;
    _rest?.dispose();
    _rest = null;

    _activeAccount = null;
    _activeVoiceGuildId = null;
    _activeVoiceChannelId = null;
    _selfMute = false;
    _selfDeaf = false;
    _voiceStateConfirmed = false;
    _voiceGatewayReady = false;
    _pendingVoiceSessionId = null;
    _pendingVoiceToken = null;
    _pendingVoiceEndpoint = null;
    _cachedDefaultSounds = null;
    _loadedSoundboardGuildIds.clear();
    _applicationEmojis = const [];
    _applicationEmojisExpires = DateTime.fromMillisecondsSinceEpoch(0);
    _pendingAppEmojisFuture = null;
    voicePingMsNotifier.value = null;
    speakingUserIdsNotifier.value = const <String>{};
    _guilds.clear();
    _dmChannels.clear();
    _messageCache.clear();
    _userProfileCache.clear();
    _lastReadMessageId.clear();
    _unreadChannelIds.clear();
    _notifications.clear();
    _unreadNotificationCount = 0;
    _selectedGuildId = null;
    _lastNonDmGuildId = null;
    _selectedChannelId = null;
    _isActivelyViewingChat = false;
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

  void _loadPersistedReadState(String botId) {
    _lastReadMessageId.clear();
    _unreadChannelIds.clear();
    final raw = _prefs?.getString('$_kReadStatePrefix$botId');
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      map.forEach((k, v) {
        if (v != null) _lastReadMessageId[k] = v.toString();
      });
    } catch (_) {}
  }

  void _scheduleSaveReadState() {
    if (_saveReadStateTimer?.isActive ?? false) return;
    _saveReadStateTimer = Timer(const Duration(seconds: 2), () {
      final botId = _activeAccount?.id;
      if (botId == null) return;
      // Keep most recent 600 channel read states
      if (_lastReadMessageId.length > 600) {
        final keys = _lastReadMessageId.keys
            .take(_lastReadMessageId.length - 600)
            .toList();
        for (final k in keys) {
          _lastReadMessageId.remove(k);
        }
      }
      _prefs?.setString(
        '$_kReadStatePrefix$botId',
        jsonEncode(_lastReadMessageId),
      );
    });
  }

  /// Syncs a channel's last_message_id with our persisted read state.
  /// First-seen channels are baseline-marked at their current lastMessageId
  /// so channels NEVER display false white unread dots on initial load.
  void _syncChannelReadBaseline(Iterable<DiscordChannel> channels) {
    bool changed = false;
    for (final ch in channels) {
      final lastMsg = ch.lastMessageId;
      if (!_lastReadMessageId.containsKey(ch.id)) {
        _lastReadMessageId[ch.id] = lastMsg ?? '0';
        changed = true;
      } else if (lastMsg != null &&
          compareSnowflakes(lastMsg, _lastReadMessageId[ch.id]) > 0) {
        if (!(_isActivelyViewingChat && _selectedChannelId == ch.id)) {
          _unreadChannelIds.add(ch.id);
        } else {
          _lastReadMessageId[ch.id] = lastMsg;
          changed = true;
        }
      }
    }
    if (changed) _scheduleSaveReadState();
  }

  void _markChannelRead(String channelId, {String? messageId}) {
    final ch = findChannelById(channelId);
    final newestId = messageId ??
        (_messageCache[channelId]?.isNotEmpty == true
            ? _messageCache[channelId]!.first.id
            : ch?.lastMessageId);
    final hadUnread = _unreadChannelIds.remove(channelId);
    if (newestId != null &&
        compareSnowflakes(newestId, _lastReadMessageId[channelId]) > 0) {
      _lastReadMessageId[channelId] = newestId;
      _scheduleSaveReadState();
    }
    if (hadUnread) {
      notifyListeners();
    }
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
      _syncChannelReadBaseline(_dmChannels.values);
    } catch (_) {}
  }

  Future<void> _savePersistedDmChannels() async {
    if (!vencord.getSetting<bool>('BotClient', 'saveDirectMessage', true)) {
      return;
    }
    final botId = _activeAccount?.id;
    if (botId == null) return;
    final list = _dmChannels.values.take(80).map((c) => c.toJson()).toList();
    await _prefs?.setString('$_kDmChannelsPrefix$botId', jsonEncode(list));
  }

  /// Fetches and caches the bot's own Application Emojis (`GET /applications/{id}/emojis`)
  /// with a 5-minute TTL matching `VencordDBCPlugin/utils/application-emojis.ts`.
  Future<List<DiscordEmoji>> loadApplicationEmojis({bool force = false}) async {
    final acc = _activeAccount;
    if (_rest == null || acc == null) return const [];
    if (!force && DateTime.now().isBefore(_applicationEmojisExpires)) {
      return _applicationEmojis;
    }
    if (_pendingAppEmojisFuture != null) return _pendingAppEmojisFuture!;

    final appId = (acc.applicationId != null && acc.applicationId!.isNotEmpty)
        ? acc.applicationId!
        : acc.id;
    final fut = _rest!.getApplicationEmojis(appId).then((items) {
      _applicationEmojis = List.unmodifiable(items);
      _applicationEmojisExpires =
          DateTime.now().add(const Duration(minutes: 5));
      notifyListeners();
      return _applicationEmojis;
    }).catchError((_) {
      _applicationEmojisExpires =
          DateTime.now().add(const Duration(seconds: 30));
      return _applicationEmojis;
    }).whenComplete(() {
      _pendingAppEmojisFuture = null;
    });
    _pendingAppEmojisFuture = fut;
    return fut;
  }

  void toggleCategoryCollapse(String categoryId) {
    if (_collapsedCategoryIds.contains(categoryId)) {
      _collapsedCategoryIds.remove(categoryId);
    } else {
      _collapsedCategoryIds.add(categoryId);
    }
    notifyListeners();
  }

  /// Flips between Direct Messages and last active Server (You Bar swipe gesture).
  Future<void> flipDmAndServer() async {
    if (_selectedGuildId == null) {
      final targetGuild = _lastNonDmGuildId ??
          (_guilds.isNotEmpty ? _guilds.keys.first : null);
      if (targetGuild != null) {
        await selectGuild(targetGuild);
      }
    } else {
      await selectDmMode();
    }
  }

  Future<void> selectDmMode() async {
    if (_selectedGuildId != null) {
      _lastNonDmGuildId = _selectedGuildId;
    }
    _selectedGuildId = null;
    if (_dmChannels.isNotEmpty) {
      final firstId = _dmChannels.keys.first;
      await selectChannel(firstId, markRead: _isActivelyViewingChat);
    } else {
      _selectedChannelId = null;
      messagesNotifier.value = const [];
      notifyListeners();
    }
  }

  Future<void> selectGuild(String guildId) async {
    _selectedGuildId = guildId;
    _lastNonDmGuildId = guildId;
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
        _syncChannelReadBaseline(guild.channels);
        notifyListeners();
      } catch (_) {}
    } else {
      _syncChannelReadBaseline(guild.channels);
    }

    final resolvedGuild = guild!;
    // Build visual Discord channel order:
    // 1. Uncategorized text/announcement channels sorted by official 3-key Discord sort
    // 2. Categories sorted by (position, snowflakeId), then each category's text channels
    final categories = resolvedGuild.channels
        .where((c) => c.isCategory)
        .toList()
      ..sort(DiscordChannel.compareCategories);
    final categoryIds = categories.map((c) => c.id).toSet();

    final orderedTextCandidates = <DiscordChannel>[];
    final uncatText = resolvedGuild.channels
        .where((c) =>
            (c.parentId == null || !categoryIds.contains(c.parentId)) &&
            c.isTopLevelChannel &&
            !c.isVoice &&
            !c.isForum &&
            canViewChannel(resolvedGuild, c))
        .toList()
      ..sort(DiscordChannel.compareGuildChannels);
    orderedTextCandidates.addAll(uncatText);

    for (final cat in categories) {
      final catText = resolvedGuild.channels
          .where((c) =>
              c.parentId == cat.id &&
              c.isTopLevelChannel &&
              !c.isVoice &&
              !c.isForum &&
              canViewChannel(resolvedGuild, c))
          .toList()
        ..sort(DiscordChannel.compareGuildChannels);
      orderedTextCandidates.addAll(catText);
    }

    if (orderedTextCandidates.isNotEmpty) {
      final firstText = orderedTextCandidates.firstWhere(
        (c) => c.type == 0,
        orElse: () => orderedTextCandidates.first,
      );
      await selectChannel(firstText.id, markRead: _isActivelyViewingChat);
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
    if (ch.isThread) {
      return DiscordPermissions.has(
          perms, DiscordPermissions.sendMessagesInThreads);
    }
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

  Future<void> selectChannel(String channelId, {bool markRead = true}) async {
    _selectedChannelId = channelId;
    typingBannerNotifier.value = null;
    if (markRead) {
      _markChannelRead(channelId);
    }
    notifyListeners();

    final chObj = findChannelById(channelId);
    if (chObj != null && chObj.isForum) {
      messagesNotifier.value = const [];
      return;
    }
    // Vencord ShowHiddenChannels safeguard: avoid fetching messages on hidden channels
    if (chObj != null &&
        !chObj.isDm &&
        selectedGuild != null &&
        !canViewChannel(selectedGuild!, chObj)) {
      messagesNotifier.value = const [];
      return;
    }

    final cached = _messageCache[channelId];
    if (cached != null) {
      _messageCache.remove(channelId);
      _messageCache[channelId] = cached;
      messagesNotifier.value = List.unmodifiable(cached);
      if (markRead && cached.isNotEmpty) {
        _markChannelRead(channelId, messageId: cached.first.id);
      }
      return;
    }

    if (_rest == null) return;
    loadingMessagesNotifier.value = true;
    messagesNotifier.value = const [];

    try {
      final fetched = await _rest!.getChannelMessages(channelId, limit: 50);
      _cacheMessageAuthorsInGuild(fetched);
      _putChannelCache(channelId, fetched);
      if (_selectedChannelId == channelId) {
        messagesNotifier.value = List.unmodifiable(fetched);
        if (markRead && fetched.isNotEmpty) {
          _markChannelRead(channelId, messageId: fetched.first.id);
        }
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

  void _cacheMessageAuthorsInGuild(Iterable<DiscordMessage> msgs) {
    for (final m in msgs) {
      final gId = m.guildId ?? _selectedGuildId;
      if (gId != null && _guilds.containsKey(gId)) {
        final g = _guilds[gId]!;
        final existing = g.cachedMembers[m.author.id];
        if (existing == null ||
            m.memberRoleIds.isNotEmpty ||
            m.memberNick != null) {
          final nextMembers = Map<String, DiscordMember>.from(g.cachedMembers);
          nextMembers[m.author.id] = DiscordMember(
            user: m.author,
            nick: m.memberNick ?? existing?.nick,
            guildAvatar: existing?.guildAvatar,
            guildBanner: existing?.guildBanner,
            roleIds: m.memberRoleIds.isNotEmpty
                ? m.memberRoleIds
                : (existing?.roleIds ?? const []),
            joinedAt: existing?.joinedAt,
          );
          _guilds[gId] = g.copyWith(cachedMembers: nextMembers);
        }
      }
    }
  }

  Future<List<DiscordChannel>> fetchForumThreads(
    DiscordChannel forumChannel,
  ) async {
    final g = selectedGuild;
    final active = <DiscordChannel>[];
    if (g != null) {
      active.addAll(
        g.channels.where((c) => c.isThread && c.parentId == forumChannel.id),
      );
    }
    if (_rest != null) {
      try {
        final archived = await _rest!.getArchivedPublicThreads(
          forumChannel.id,
          guildId: forumChannel.guildId,
        );
        final existingIds = active.map((t) => t.id).toSet();
        for (final t in archived) {
          if (!existingIds.contains(t.id)) {
            active.add(t);
          }
        }
        // Merge discovered threads into guild so selectChannel can resolve them
        if (g != null && archived.isNotEmpty) {
          final mergedCh = List<DiscordChannel>.from(g.channels);
          final gIds = mergedCh.map((c) => c.id).toSet();
          for (final t in archived) {
            if (!gIds.contains(t.id)) mergedCh.add(t);
          }
          _guilds[g.id] = g.copyWith(channels: mergedCh);
        }
      } catch (_) {}
    }
    return active;
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
        _cacheMessageAuthorsInGuild(older);
        final existingIds = current.map((m) => m.id).toSet();
        final merged = <DiscordMessage>[
          ...current,
          ...older.where((m) => !existingIds.contains(m.id)),
        ];
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

  /// Built-in commands matching VencordDBCPlugin/index.tsx (/ping, /purge, /switch shard, /switch guild)
  Future<String?> tryExecuteBuiltInCommand(String rawInput) async {
    final trimmed = rawInput.trim();
    if (!trimmed.startsWith('/')) return null;
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) return null;

    final parts = trimmed.split(RegExp(r'\s+'));
    final cmd = parts.first.toLowerCase();

    if (cmd == '/ping') {
      await sendChatMessage(content: 'Pong!');
      return 'Pong!';
    }

    if (cmd == '/purge') {
      final amount = parts.length >= 2 ? (int.tryParse(parts[1]) ?? -1) : -1;
      if (amount < 2 || amount > 100) {
        throw const DiscordApiException(400, '/purge 數量必須介於 2 到 100 之間');
      }
      final cutoffMs =
          DateTime.now().millisecondsSinceEpoch - (14 * 86400 * 1000);
      final minSnowflake =
          BigInt.from(cutoffMs - 1420070400000) << 22;
      final recent = await _rest!.getChannelMessages(chId, limit: amount);
      final validIds = recent
          .where((m) => (BigInt.tryParse(m.id) ?? BigInt.zero) > minSnowflake)
          .map((m) => m.id)
          .toList();
      if (validIds.length < 2) {
        throw const DiscordApiException(
            400, '可批次刪除的訊息不足 2 則（僅能刪除 14 天內的訊息）');
      }
      await _rest!.bulkDeleteMessages(chId, validIds);
      final idSet = validIds.toSet();
      if (_messageCache.containsKey(chId)) {
        final next =
            _messageCache[chId]!.where((m) => !idSet.contains(m.id)).toList();
        _messageCache[chId] = next;
        if (_selectedChannelId == chId) {
          messagesNotifier.value = List.unmodifiable(next);
        }
      }
      return '已批次刪除 ${validIds.length} 則訊息';
    }

    if (cmd == '/switch' && parts.length >= 3) {
      final sub = parts[1].toLowerCase();
      if (sub == 'shard') {
        final id = int.tryParse(parts[2]) ?? -1;
        if (id < 0 || id >= totalShards) {
          throw DiscordApiException(
              400, 'Shard ID 必須介於 0 到 ${totalShards - 1} 之間');
        }
        await _gateway?.switchShard(id);
        return '已切換至 Shard $id / $totalShards';
      } else if (sub == 'guild') {
        final gId = parts[2];
        final gBig = BigInt.tryParse(gId);
        if (gBig == null) {
          throw const DiscordApiException(400, '無效的伺服器 ID');
        }
        if (totalShards > 1) {
          final targetShard =
              ((gBig >> 22) % BigInt.from(totalShards)).toInt();
          if (targetShard != currentShard) {
            await _gateway?.switchShard(targetShard);
          }
        }
        if (_guilds.containsKey(gId)) {
          await selectGuild(gId);
        }
        return '已切換至伺服器 $gId';
      }
    }

    // /override bitrate <value> from VencordDBCPlugin/index.tsx
    if (cmd == '/override' &&
        parts.length >= 3 &&
        parts[1].toLowerCase() == 'bitrate') {
      if (!vencord.getSetting<bool>(
          'BotClient', 'overrideVoiceChannelBitrate', false)) {
        throw const DiscordApiException(
          400,
          '請先於 設定 > Vencord > BotClient 開啟 Override Voice Channel Bitrate',
        );
      }
      final kbps = int.tryParse(parts[2]) ?? -1;
      if (kbps < 6 || kbps > 5000) {
        throw const DiscordApiException(
          400,
          'Bitrate 數值必須介於 6 到 5000 Kbps 之間',
        );
      }
      await vencord.setPluginSetting(
        'BotClient',
        'bitrateVoiceChannel',
        kbps,
        _prefs,
      );
      return '已將預設語音位元率覆寫設定為 $kbps Kbps';
    }

    // Execute any enabled Custom Vencord Userplugin commands
    final bareCmd = cmd.substring(1);
    for (final customCmd in vencord.enabledCustomCommands) {
      if (customCmd.name.toLowerCase() == bareCmd) {
        final argsText =
            parts.length > 1 ? parts.sublist(1).join(' ') : '';
        final tpl = customCmd.responseTemplate ?? 'Executed /${customCmd.name}';
        final resolved = tpl.replaceAll('{args}', argsText).trim();
        if (customCmd.sendToChannel && resolved.isNotEmpty) {
          await sendChatMessage(content: resolved);
          return 'Pong!';
        }
        return resolved;
      }
    }

    return null;
  }

  Future<DiscordMessage> sendChatMessage({
    String content = '',
    String? replyToMessageId,
    bool replyMention = true,
    bool silentMessage = false,
    List<DiscordEmbed>? embeds,
    Map<String, dynamic>? rawPayloadOverride,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) {
      throw const DiscordApiException(400, '尚未選擇頻道');
    }

    var processedContent = rawPayloadOverride == null
        ? vencord.applyPreSendContentHooks(content)
        : content;

    if (rawPayloadOverride == null &&
        processedContent.isNotEmpty &&
        vencord.isPluginEnabled('Translate') &&
        vencord.getSetting<bool>('Translate', 'autoTranslate', false)) {
      try {
        final targetLang =
            vencord.getSetting<String>('Translate', 'sentTarget', 'en');
        processedContent = await _rest!.translateText(
          processedContent,
          targetLang: targetLang,
        );
      } catch (_) {}
    }

    final finalFileName =
        fileName != null ? vencord.maybeAnonymiseFileName(fileName) : null;

    final sent = await _rest!.sendMessage(
      chId,
      content: processedContent,
      replyToMessageId: replyToMessageId,
      replyMention: replyMention,
      flags: silentMessage ? (1 << 12) : null,
      embeds: embeds,
      rawPayloadOverride: rawPayloadOverride,
      fileBytes: fileBytes,
      fileName: finalFileName,
    );
    _insertOrUpdateMessage(chId, sent, isNew: true);
    _markChannelRead(chId, messageId: sent.id);
    return sent;
  }

  Future<void> editChatMessage(
    String messageId, {
    String? newContent,
    List<DiscordEmbed>? embeds,
    Map<String, dynamic>? rawPayloadOverride,
  }) async {
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) return;
    final updated = await _rest!.editMessage(
      chId,
      messageId,
      content: newContent,
      embeds: embeds,
      rawPayloadOverride: rawPayloadOverride,
    );
    _insertOrUpdateMessage(chId, updated, isNew: false);
  }

  Future<void> translateMessageInline(DiscordMessage message) async {
    if (_rest == null) return;
    if (message.translatedText != null) {
      _insertOrUpdateMessage(
        message.channelId,
        message.copyWith(clearTranslatedText: true),
        isNew: false,
      );
      return;
    }
    final source = message.content.trim().isNotEmpty
        ? message.content.trim()
        : (message.embeds.isNotEmpty
            ? (message.embeds.first.description ?? message.embeds.first.title ?? '')
            : '');
    if (source.isEmpty) return;
    final targetLang =
        vencord.getSetting<String>('Translate', 'receivedTarget', 'zh-TW');
    final translated = await _rest!.translateText(
      source,
      targetLang: targetLang,
    );
    _insertOrUpdateMessage(
      message.channelId,
      message.copyWith(translatedText: translated),
      isNew: false,
    );
  }

  void clearLoggedMessageHistory(DiscordMessage message) {
    final chId = message.channelId;
    final existing = _messageCache[chId];
    if (existing == null) return;
    if (message.isDeleted) {
      final next = existing.where((m) => m.id != message.id).toList();
      _messageCache[chId] = next;
      if (_selectedChannelId == chId) {
        messagesNotifier.value = List.unmodifiable(next);
      }
    } else {
      _insertOrUpdateMessage(
        chId,
        message.copyWith(editHistory: const []),
        isNew: false,
      );
    }
  }

  bool _shouldMessageLoggerCapture(DiscordMessage msg, {required bool isDelete}) {
    if (!vencord.isPluginEnabled('MessageLogger')) return false;
    final flag = isDelete
        ? vencord.getSetting<bool>('MessageLogger', 'logDeletes', true)
        : vencord.getSetting<bool>('MessageLogger', 'logEdits', true);
    if (!flag) return false;
    if (vencord.getSetting<bool>('MessageLogger', 'ignoreBots', false) &&
        msg.author.bot &&
        msg.author.id != _activeAccount?.id) {
      return false;
    }
    if (vencord.getSetting<bool>('MessageLogger', 'ignoreSelf', false) &&
        msg.author.id == _activeAccount?.id) {
      return false;
    }
    return true;
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
    if (vencord.isPluginEnabled('SilentTyping') &&
        vencord.getSetting<bool>('SilentTyping', 'isEnabled', true)) {
      return;
    }
    if (_ecoSettings.silentTyping || _ecoSettings.ecoPowerSaving) return;
    final chId = _selectedChannelId;
    if (chId == null || _rest == null) return;
    final now = DateTime.now();
    if (now.difference(_lastTypingTriggerSent).inSeconds >= 8) {
      _lastTypingTriggerSent = now;
      unawaited(_rest!.triggerTyping(chId).catchError((_) {}));
    }
  }

  DiscordUser? getCachedUser(String userId) {
    if (_userProfileCache.containsKey(userId)) {
      return _userProfileCache[userId];
    }
    for (final dm in _dmChannels.values) {
      for (final u in dm.recipients) {
        if (u.id == userId) return u;
      }
    }
    for (final g in _guilds.values) {
      final m = g.cachedMembers[userId];
      if (m != null) return m.user;
    }
    return null;
  }

  /// Fetches and caches full User Profile (`banner`, `accent_color`, `public_flags`)
  /// and optional Guild Member details (`roles`, `nick`, `joined_at`, `avatar`).
  Future<(DiscordUser?, DiscordMember?)> fetchRichUserProfile(
    String userId, {
    String? guildId,
  }) async {
    DiscordUser? user = _userProfileCache[userId];
    DiscordMember? member =
        guildId != null ? _guilds[guildId]?.cachedMembers[userId] : null;

    if (_rest == null) return (user, member);

    final futures = <Future<void>>[];

    if (user == null || !user.profileFetched) {
      futures.add(() async {
        try {
          final fetchedUser = await _rest!.getUser(userId);
          _userProfileCache.remove(userId);
          _userProfileCache[userId] = fetchedUser;
          while (_userProfileCache.length > 120) {
            _userProfileCache.remove(_userProfileCache.keys.first);
          }
          user = fetchedUser;
        } catch (_) {}
      }());
    }

    if (guildId != null && (member == null || member.joinedAt == null)) {
      futures.add(() async {
        try {
          final fetchedMember = await _rest!.getGuildMember(guildId, userId);
          member = fetchedMember;
          final g = _guilds[guildId];
          if (g != null) {
            final nextMembers = Map<String, DiscordMember>.from(g.cachedMembers);
            nextMembers[userId] = fetchedMember;
            _guilds[guildId] = g.copyWith(cachedMembers: nextMembers);
          }
        } catch (_) {}
      }());
    }

    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
    return (user, member);
  }

  Future<DiscordChannel> openDmWithUser(
    String userId, {
    bool targetIsBot = false,
  }) async {
    if (_rest == null) {
      throw const DiscordApiException(400, '尚未登入');
    }
    if (targetIsBot) {
      throw const DiscordApiException(400, '無法傳送私人訊息給其他機器人');
    }
    if (userId.trim() == _activeAccount?.id) {
      throw const DiscordApiException(400, '無法與自己開啟私訊');
    }
    final dm = await _rest!.createDirectMessage(userId);
    if (dm.dmRecipient?.bot == true) {
      throw const DiscordApiException(400, '無法傳送私人訊息給其他機器人');
    }
    _dmChannels.remove(dm.id);
    final existing = Map<String, DiscordChannel>.from(_dmChannels);
    _dmChannels
      ..clear()
      ..[dm.id] = dm
      ..addAll(existing);
    _syncChannelReadBaseline([dm]);
    await _savePersistedDmChannels();
    if (_selectedGuildId != null) {
      _lastNonDmGuildId = _selectedGuildId;
    }
    _selectedGuildId = null;
    await selectChannel(dm.id, markRead: true);
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

  // ==========================================================
  // Voice Channel Connection Management (Opcode 4 + Voice WS)
  // ==========================================================
  void _ensureVoiceServiceInitialized() {
    if (_voiceService != null) return;
    _voiceService = DiscordVoiceService(
      onSpeakingChanged: (uid, isSpeaking) {
        final cur = speakingUserIdsNotifier.value;
        if (isSpeaking && !cur.contains(uid)) {
          speakingUserIdsNotifier.value = <String>{...cur, uid};
        } else if (!isSpeaking && cur.contains(uid)) {
          final next = Set<String>.from(cur)..remove(uid);
          speakingUserIdsNotifier.value = next;
        }
      },
      onVoicePingUpdated: (ms) {
        voicePingMsNotifier.value = ms;
      },
      onConnectionChanged: (connected) {
        if (_voiceGatewayReady != connected) {
          _voiceGatewayReady = connected;
          notifyListeners();
        }
      },
    );
  }

  Future<void> joinVoiceChannel(
    String guildId,
    String channelId, {
    bool startMuted = false,
  }) async {
    if (_gateway == null) return;
    _ensureVoiceServiceInitialized();

    // If switching from another guild's voice channel, disconnect previous guild first (matching VencordDBCPlugin/utils/patches.ts!)
    final prevGuildId = _activeVoiceGuildId;
    final botId = _activeAccount?.id;
    final sameGuild = prevGuildId == guildId;
    if (prevGuildId != null && !sameGuild) {
      if (botId != null && _guilds.containsKey(prevGuildId)) {
        final pg = _guilds[prevGuildId]!;
        final nextPrevVs = Map<String, VoiceState>.from(pg.voiceStates)
          ..remove(botId);
        _guilds[prevGuildId] = pg.copyWith(voiceStates: nextPrevVs);
      }
      _gateway!.sendVoiceStateUpdate(
        guildId: prevGuildId,
        channelId: null,
        selfMute: _selfMute,
        selfDeaf: _selfDeaf,
      );
      await _voiceService?.disconnect(notify: false);
      _pendingVoiceSessionId = null;
      _pendingVoiceToken = null;
      _pendingVoiceEndpoint = null;
      _voiceGatewayReady = false;
    }

    _activeVoiceGuildId = guildId;
    _activeVoiceChannelId = channelId;
    _voiceStateConfirmed = false;
    _selfMute = startMuted;
    if (_selfDeaf && !startMuted) {
      _selfMute = true;
    }
    speakingUserIdsNotifier.value = const <String>{};

    // Optimistic local voice_state update for 0ms UI feedback before Gateway round-trip
    if (botId != null && _guilds.containsKey(guildId)) {
      final g = _guilds[guildId]!;
      final nextVs = Map<String, VoiceState>.from(g.voiceStates);
      nextVs[botId] = VoiceState(
        guildId: guildId,
        channelId: channelId,
        userId: botId,
        sessionId: _pendingVoiceSessionId ?? '',
        selfMute: _selfMute,
        selfDeaf: _selfDeaf,
        member: g.cachedMembers[botId],
      );
      _guilds[guildId] = g.copyWith(voiceStates: nextVs);
    }

    _gateway!.sendVoiceStateUpdate(
      guildId: guildId,
      channelId: channelId,
      selfMute: _selfMute,
      selfDeaf: _selfDeaf,
    );
    notifyListeners();
  }

  void toggleVoiceMute() {
    if (_activeVoiceGuildId == null ||
        _activeVoiceChannelId == null ||
        _gateway == null) {
      return;
    }
    _selfMute = !_selfMute;
    if (!_selfMute && _selfDeaf) {
      _selfDeaf = false;
    }
    _syncOptimisticBotVoiceFlags();
    _gateway!.sendVoiceStateUpdate(
      guildId: _activeVoiceGuildId!,
      channelId: _activeVoiceChannelId,
      selfMute: _selfMute,
      selfDeaf: _selfDeaf,
    );
    notifyListeners();
  }

  void toggleVoiceDeaf() {
    if (_activeVoiceGuildId == null ||
        _activeVoiceChannelId == null ||
        _gateway == null) {
      return;
    }
    _selfDeaf = !_selfDeaf;
    if (_selfDeaf) {
      _selfMute = true;
    }
    _syncOptimisticBotVoiceFlags();
    _gateway!.sendVoiceStateUpdate(
      guildId: _activeVoiceGuildId!,
      channelId: _activeVoiceChannelId,
      selfMute: _selfMute,
      selfDeaf: _selfDeaf,
    );
    notifyListeners();
  }

  void _syncOptimisticBotVoiceFlags() {
    final gId = _activeVoiceGuildId;
    final chId = _activeVoiceChannelId;
    final botId = _activeAccount?.id;
    if (gId == null || chId == null || botId == null) return;
    final g = _guilds[gId];
    if (g == null) return;
    final prev = g.voiceStates[botId];
    final nextVs = Map<String, VoiceState>.from(g.voiceStates);
    nextVs[botId] = VoiceState(
      guildId: gId,
      channelId: chId,
      userId: botId,
      sessionId: prev?.sessionId ?? _pendingVoiceSessionId ?? '',
      mute: prev?.mute ?? false,
      deaf: prev?.deaf ?? false,
      selfMute: _selfMute,
      selfDeaf: _selfDeaf,
      suppress: prev?.suppress ?? false,
      member: prev?.member ?? g.cachedMembers[botId],
    );
    _guilds[gId] = g.copyWith(voiceStates: nextVs);
  }

  Future<void> leaveVoiceChannel() async {
    final prevGuild = _activeVoiceGuildId;
    final botId = _activeAccount?.id;
    if (prevGuild != null && botId != null && _guilds.containsKey(prevGuild)) {
      final g = _guilds[prevGuild]!;
      final nextVs = Map<String, VoiceState>.from(g.voiceStates)..remove(botId);
      _guilds[prevGuild] = g.copyWith(voiceStates: nextVs);
    }
    _activeVoiceGuildId = null;
    _activeVoiceChannelId = null;
    _voiceStateConfirmed = false;
    _voiceGatewayReady = false;
    _pendingVoiceSessionId = null;
    _pendingVoiceToken = null;
    _pendingVoiceEndpoint = null;
    speakingUserIdsNotifier.value = const <String>{};
    await _voiceService?.disconnect(notify: false);
    if (prevGuild != null) {
      _gateway?.sendVoiceStateUpdate(
        guildId: prevGuild,
        channelId: null,
        selfMute: _selfMute,
        selfDeaf: _selfDeaf,
      );
    }
    notifyListeners();
  }

  /// Loads custom Soundboard sounds for [guildId] + Discord's default Soundboard sounds.
  Future<(List<SoundboardSound> guildSounds, List<SoundboardSound> otherGuildSounds, List<SoundboardSound> defaultSounds)>
      loadSoundboardSounds(String guildId) async {
    if (_rest != null) {
      final tasks = <Future<void>>[];
      if (_cachedDefaultSounds == null) {
        tasks.add(() async {
          try {
            _cachedDefaultSounds = await _rest!.getDefaultSoundboardSounds();
          } catch (_) {
            _cachedDefaultSounds = const [];
          }
        }());
      }
      if (!_loadedSoundboardGuildIds.contains(guildId)) {
        tasks.add(() async {
          try {
            final fetched = await _rest!.getGuildSoundboardSounds(guildId);
            _loadedSoundboardGuildIds.add(guildId);
            final g = _guilds[guildId];
            if (g != null && fetched.isNotEmpty) {
              _guilds[guildId] = g.copyWith(soundboardSounds: fetched);
            }
          } catch (_) {
            _loadedSoundboardGuildIds.add(guildId);
          }
        }());
      }
      if (tasks.isNotEmpty) {
        await Future.wait(tasks);
      }
    }

    final currentSounds =
        _guilds[guildId]?.soundboardSounds ?? const <SoundboardSound>[];
    final otherSounds = <SoundboardSound>[];
    for (final g in _guilds.values) {
      if (g.id != guildId && g.soundboardSounds.isNotEmpty) {
        otherSounds.addAll(g.soundboardSounds);
      }
    }
    return (
      currentSounds,
      otherSounds,
      _cachedDefaultSounds ?? const <SoundboardSound>[],
    );
  }

  /// Plays a Soundboard sound in [channelId]. Automatically unmutes selfMute/selfDeaf
  /// if muted so Discord's Soundboard API accepts the broadcast.
  Future<void> playSoundboardSound(
    String channelId,
    SoundboardSound sound,
  ) async {
    if (_rest == null) {
      throw const DiscordApiException(400, '尚未登入');
    }
    final gId = _activeVoiceGuildId;
    if (gId == null || _activeVoiceChannelId != channelId) {
      throw const DiscordApiException(400, '請先加入此語音頻道再播放音效板');
    }
    final botId = _activeAccount?.id;
    final botVs = botId != null ? _guilds[gId]?.voiceStates[botId] : null;
    if (botVs != null && (botVs.mute || botVs.deaf || botVs.suppress)) {
      throw const DiscordApiException(403, '機器人目前被伺服器靜音或處於舞台聽眾席，無法播放音效板');
    }

    // Discord rejects send-soundboard-sound if self_mute or self_deaf is true
    if (_selfMute || _selfDeaf) {
      _selfMute = false;
      _selfDeaf = false;
      _syncOptimisticBotVoiceFlags();
      _gateway?.sendVoiceStateUpdate(
        guildId: gId,
        channelId: channelId,
        selfMute: false,
        selfDeaf: false,
      );
      notifyListeners();
      await Future<void>.delayed(const Duration(milliseconds: 220));
    }

    final isExternal = sound.guildId != null && sound.guildId != gId;
    await _rest!.sendSoundboardSound(
      channelId,
      soundId: sound.soundId,
      sourceGuildId: isExternal ? sound.guildId : null,
    );
  }

  void _tryConnectVoiceSocket() {
    if (_activeVoiceGuildId == null ||
        _activeAccount == null ||
        _pendingVoiceSessionId == null ||
        _pendingVoiceToken == null ||
        _pendingVoiceEndpoint == null) {
      return;
    }
    _ensureVoiceServiceInitialized();
    unawaited(_voiceService!.connect(
      guildId: _activeVoiceGuildId!,
      userId: _activeAccount!.id,
      sessionId: _pendingVoiceSessionId!,
      voiceToken: _pendingVoiceToken!,
      endpoint: _pendingVoiceEndpoint!,
    ));
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
          final prev = _guilds[parsed.id];
          final mergedGuild = prev != null && parsed.voiceStates.isEmpty
              ? parsed.copyWith(voiceStates: prev.voiceStates)
              : parsed;
          _guilds[parsed.id] = mergedGuild;

          // If bot is already connected in a voice channel on GUILD_CREATE, sync state
          final botId = _activeAccount?.id;
          if (botId != null && mergedGuild.voiceStates.containsKey(botId)) {
            final ownVs = mergedGuild.voiceStates[botId]!;
            if (ownVs.channelId != null && ownVs.channelId!.isNotEmpty) {
              _activeVoiceGuildId = parsed.id;
              _activeVoiceChannelId = ownVs.channelId;
              _voiceStateConfirmed = true;
              _selfMute = ownVs.selfMute;
              _selfDeaf = ownVs.selfDeaf;
              if (ownVs.sessionId.isNotEmpty) {
                _pendingVoiceSessionId = ownVs.sessionId;
              }
            }
          }
          _syncChannelReadBaseline(parsed.channels);
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

      case 'VOICE_STATE_UPDATE':
        if (data is Map<String, dynamic>) {
          final vs = VoiceState.fromJson(data);
          final gId = vs.guildId;
          if (gId != null && _guilds.containsKey(gId)) {
            final g = _guilds[gId]!;
            final nextVs = Map<String, VoiceState>.from(g.voiceStates);
            final nextMembers = Map<String, DiscordMember>.from(g.cachedMembers);
            if (vs.member != null && vs.member!.user.id != '0') {
              nextMembers[vs.member!.user.id] = vs.member!;
            }
            if (vs.channelId == null || vs.channelId!.isEmpty) {
              nextVs.remove(vs.userId);
              if (speakingUserIdsNotifier.value.contains(vs.userId)) {
                final nextSpk = Set<String>.from(speakingUserIdsNotifier.value)
                  ..remove(vs.userId);
                speakingUserIdsNotifier.value = nextSpk;
              }
            } else {
              nextVs[vs.userId] = vs;
            }
            _guilds[gId] = g.copyWith(
              voiceStates: nextVs,
              cachedMembers: nextMembers,
            );
          }

          // Check if this is our own Bot's voice state update!
          if (vs.userId == _activeAccount?.id) {
            if (vs.channelId == null || vs.channelId!.isEmpty) {
              if (gId == _activeVoiceGuildId) {
                _activeVoiceGuildId = null;
                _activeVoiceChannelId = null;
                _voiceStateConfirmed = false;
                _voiceGatewayReady = false;
                unawaited(_voiceService?.disconnect(notify: false));
              }
            } else {
              _activeVoiceGuildId = gId ?? _activeVoiceGuildId;
              _activeVoiceChannelId = vs.channelId;
              _voiceStateConfirmed = true;
              _selfMute = vs.selfMute;
              _selfDeaf = vs.selfDeaf;
              if (vs.sessionId.isNotEmpty) {
                final sessionChanged = _pendingVoiceSessionId != vs.sessionId;
                _pendingVoiceSessionId = vs.sessionId;
                if (sessionChanged || !_voiceGatewayReady) {
                  _tryConnectVoiceSocket();
                }
              }
            }
          }
          _scheduleCoalescedNotify();
        }
        break;

      case 'VOICE_SERVER_UPDATE':
        if (data is Map<String, dynamic>) {
          final gId = data['guild_id']?.toString();
          final vToken = data['token']?.toString();
          final endpoint = data['endpoint']?.toString();
          if (gId == _activeVoiceGuildId &&
              vToken != null &&
              endpoint != null &&
              endpoint.isNotEmpty) {
            _pendingVoiceToken = vToken;
            _pendingVoiceEndpoint = endpoint;
            _tryConnectVoiceSocket();
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
              banner: updated.banner,
              features: updated.features.isNotEmpty
                  ? updated.features
                  : prev.features,
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
          _syncChannelReadBaseline([ch]);
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
            _unreadChannelIds.remove(chId);
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
          _cacheMessageAuthorsInGuild([msg]);

          final botId = _activeAccount?.id;
          // Update lastMessageId on guild or DM channel
          if (msg.guildId == null) {
            if (msg.author.id != botId) {
              if (!_dmChannels.containsKey(msg.channelId)) {
                _dmChannels[msg.channelId] = DiscordChannel(
                  id: msg.channelId,
                  name: msg.author.displayName,
                  type: 1,
                  lastMessageId: msg.id,
                  recipients: [msg.author],
                );
              } else {
                _dmChannels[msg.channelId] = _dmChannels[msg.channelId]!
                    .copyWith(lastMessageId: msg.id);
              }
              unawaited(_savePersistedDmChannels());
            }
          } else if (_guilds.containsKey(msg.guildId)) {
            final g = _guilds[msg.guildId]!;
            final chList = List<DiscordChannel>.from(g.channels);
            final cIdx = chList.indexWhere((c) => c.id == msg.channelId);
            if (cIdx != -1) {
              chList[cIdx] = chList[cIdx].copyWith(lastMessageId: msg.id);
              _guilds[g.id] = g.copyWith(channels: chList);
            }
          }

          if (botId != null && msg.author.id != botId) {
            final mentionsBot = msg.content.contains('<@$botId>') ||
                msg.content.contains('<@!$botId>') ||
                msg.referencedMessage?.author.id == botId ||
                msg.guildId == null;
            if (mentionsBot) {
              _notifications.insert(0, msg);
              if (_notifications.length > 50) {
                _notifications.removeRange(50, _notifications.length);
              }
              _unreadNotificationCount++;
              _scheduleCoalescedNotify();
            }
          }

          _insertOrUpdateMessage(msg.channelId, msg, isNew: true);

          final isOpenNow =
              _isActivelyViewingChat && _selectedChannelId == msg.channelId;
          if (isOpenNow || msg.author.id == botId) {
            _lastReadMessageId[msg.channelId] = msg.id;
            _scheduleSaveReadState();
            if (msg.channelId == _selectedChannelId) {
              typingBannerNotifier.value = null;
            }
          } else {
            _unreadChannelIds.add(msg.channelId);
            _scheduleCoalescedNotify();
          }
        }
        break;

      case 'MESSAGE_UPDATE':
        if (data is Map<String, dynamic>) {
          final chId = data['channel_id']?.toString();
          final msgId = data['id']?.toString();
          if (chId != null &&
              msgId != null &&
              _messageCache.containsKey(chId)) {
            final list = _messageCache[chId]!;
            final idx = list.indexWhere((m) => m.id == msgId);
            if (idx != -1) {
              final existing = list[idx];
              final incomingContent = data['content'] as String?;
              List<MessageEditLogEntry> nextHistory = existing.editHistory;
              if (incomingContent != null &&
                  incomingContent != existing.content &&
                  existing.content.isNotEmpty &&
                  _shouldMessageLoggerCapture(existing, isDelete: false)) {
                nextHistory = [
                  ...existing.editHistory,
                  MessageEditLogEntry(
                    timestamp: DateTime.now(),
                    content: existing.content,
                  ),
                ];
              }
              final updated = existing.copyWith(
                content: incomingContent ?? existing.content,
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
                editHistory: nextHistory,
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
            final cachedList = _messageCache[chId];
            final idx = cachedList?.indexWhere((m) => m.id == msgId) ?? -1;
            if (idx >= 0 &&
                _shouldMessageLoggerCapture(cachedList![idx], isDelete: true)) {
              _insertOrUpdateMessage(
                chId,
                cachedList[idx].copyWith(isDeleted: true),
                isNew: false,
              );
            } else {
              _removeMessageFromCache(chId, msgId);
            }
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
            final next = <DiscordMessage>[];
            for (final m in _messageCache[chId]!) {
              if (!ids.contains(m.id)) {
                next.add(m);
              } else if (_shouldMessageLoggerCapture(m, isDelete: true)) {
                next.add(m.copyWith(isDeleted: true));
              }
            }
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
                  'Someone';
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
      list.insert(0, msg);
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
    voicePingMsNotifier.dispose();
    speakingUserIdsNotifier.dispose();
    gatewayEventsCountNotifier.dispose();
    messagesNotifier.dispose();
    loadingMessagesNotifier.dispose();
    typingBannerNotifier.dispose();
    super.dispose();
  }
}
