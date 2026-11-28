import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../ui/theme/app_theme.dart';

enum VencordOptionType {
  string,
  number,
  boolean,
  select,
}

class VencordSelectOption {
  final String label;
  final Object value;
  final bool isDefault;

  const VencordSelectOption({
    required this.label,
    required this.value,
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        'default': isDefault,
      };

  factory VencordSelectOption.fromJson(Map<String, dynamic> json) {
    return VencordSelectOption(
      label: json['label']?.toString() ?? '',
      value: json['value'] ?? '',
      isDefault: json['default'] as bool? ?? false,
    );
  }
}

class VencordSettingDef {
  final String key;
  final String description;
  final VencordOptionType type;
  final Object? defaultValue;
  final List<VencordSelectOption> options;
  final bool restartNeeded;

  const VencordSettingDef({
    required this.key,
    required this.description,
    required this.type,
    this.defaultValue,
    this.options = const [],
    this.restartNeeded = false,
  });

  Object? get resolvedDefault {
    if (defaultValue != null) return defaultValue;
    if (type == VencordOptionType.select && options.isNotEmpty) {
      for (final o in options) {
        if (o.isDefault) return o.value;
      }
      return options.first.value;
    }
    if (type == VencordOptionType.boolean) return false;
    if (type == VencordOptionType.number) return 0;
    return '';
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'description': description,
        'type': type.name,
        'defaultValue': defaultValue,
        'options': options.map((e) => e.toJson()).toList(),
        'restartNeeded': restartNeeded,
      };

  factory VencordSettingDef.fromJson(Map<String, dynamic> json) {
    final typeName = json['type']?.toString() ?? 'string';
    final parsedType = VencordOptionType.values.firstWhere(
      (e) => e.name == typeName,
      orElse: () => VencordOptionType.string,
    );
    final rawOpts = json['options'] as List<dynamic>? ?? const [];
    return VencordSettingDef(
      key: json['key']?.toString() ?? 'setting',
      description: json['description']?.toString() ?? '',
      type: parsedType,
      defaultValue: json['defaultValue'],
      options: rawOpts
          .whereType<Map<String, dynamic>>()
          .map(VencordSelectOption.fromJson)
          .toList(),
      restartNeeded: json['restartNeeded'] as bool? ?? false,
    );
  }
}

class VencordPluginCommand {
  final String name;
  final String description;
  final String? responseTemplate;
  final bool sendToChannel;

  const VencordPluginCommand({
    required this.name,
    required this.description,
    this.responseTemplate,
    this.sendToChannel = true,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        if (responseTemplate != null) 'responseTemplate': responseTemplate,
        'sendToChannel': sendToChannel,
      };

  factory VencordPluginCommand.fromJson(Map<String, dynamic> json) {
    return VencordPluginCommand(
      name: json['name']?.toString() ?? 'cmd',
      description: json['description']?.toString() ?? '',
      responseTemplate: json['responseTemplate'] as String?,
      sendToChannel: json['sendToChannel'] as bool? ?? true,
    );
  }
}

class VencordTextRule {
  final String find;
  final String replace;
  final String onlyIfIncludes;
  final bool isRegex;

  const VencordTextRule({
    required this.find,
    required this.replace,
    this.onlyIfIncludes = '',
    this.isRegex = false,
  });

  Map<String, dynamic> toJson() => {
        'find': find,
        'replace': replace,
        'onlyIfIncludes': onlyIfIncludes,
        'isRegex': isRegex,
      };

  factory VencordTextRule.fromJson(Map<String, dynamic> json) {
    return VencordTextRule(
      find: json['find']?.toString() ?? '',
      replace: json['replace']?.toString() ?? '',
      onlyIfIncludes: json['onlyIfIncludes']?.toString() ?? '',
      isRegex: json['isRegex'] as bool? ?? false,
    );
  }
}

class VencordPluginDef {
  final String name;
  final String description;
  final List<String> authors;
  final List<String> tags;
  final bool required;
  final bool enabledByDefault;
  final bool isCustom;
  final String? sourceUrl;
  final List<VencordSettingDef> settings;
  final List<VencordPluginCommand> commands;
  final List<VencordTextRule> preSendRules;
  final String? managedStyle;

  const VencordPluginDef({
    required this.name,
    required this.description,
    this.authors = const ['Vendicated'],
    this.tags = const ['Utility'],
    this.required = false,
    this.enabledByDefault = false,
    this.isCustom = false,
    this.sourceUrl,
    this.settings = const [],
    this.commands = const [],
    this.preSendRules = const [],
    this.managedStyle,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'authors': authors,
        'tags': tags,
        'required': required,
        'enabledByDefault': enabledByDefault,
        'isCustom': isCustom,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
        'settings': settings.map((e) => e.toJson()).toList(),
        'commands': commands.map((e) => e.toJson()).toList(),
        'preSendRules': preSendRules.map((e) => e.toJson()).toList(),
        if (managedStyle != null) 'managedStyle': managedStyle,
      };

  factory VencordPluginDef.fromJson(Map<String, dynamic> json) {
    return VencordPluginDef(
      name: json['name']?.toString() ?? 'CustomPlugin',
      description: json['description']?.toString() ?? '',
      authors: (json['authors'] as List<dynamic>? ?? const ['Custom'])
          .map((e) => e.toString())
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? const ['Custom'])
          .map((e) => e.toString())
          .toList(),
      required: json['required'] as bool? ?? false,
      enabledByDefault: json['enabledByDefault'] as bool? ?? true,
      isCustom: true,
      sourceUrl: json['sourceUrl'] as String?,
      settings: (json['settings'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VencordSettingDef.fromJson)
          .toList(),
      commands: (json['commands'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VencordPluginCommand.fromJson)
          .toList(),
      preSendRules: (json['preSendRules'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(VencordTextRule.fromJson)
          .toList(),
      managedStyle: json['managedStyle'] as String?,
    );
  }
}

/// Built-in official Vencord plugins matching `Vendicated/Vencord` & `aiko-chan-ai/VencordDBCPlugin`!
const List<VencordPluginDef> kBuiltInVencordPlugins = [
  VencordPluginDef(
    name: 'BotClient',
    description:
        'Patch Discord to allow the use of bot accounts, Application Emojis, Embed/Components V2 Editor, /ping, /purge, /switch & /override.',
    authors: ['Elysia'],
    tags: ['Core', 'BotClient', 'Commands'],
    required: true,
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'showMemberList',
        description: 'Allow fetching member list sidebar',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'memberListThrottleDelay',
        description:
            'The interval at which the member list sidebar is updated (seconds)',
        type: VencordOptionType.number,
        defaultValue: 2,
      ),
      VencordSettingDef(
        key: 'messageEditor',
        description: 'Choose which editor the chat bar and message buttons open',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(
            label: 'Advanced Message Editor (Components V2 & JSON)',
            value: 'advanced',
            isDefault: true,
          ),
          VencordSelectOption(
            label: 'Embed Editor (Legacy)',
            value: 'legacy',
          ),
        ],
      ),
      VencordSettingDef(
        key: 'embedChatButton',
        description: 'Show the message editor button in the chat bar',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'embedEditMessageButton',
        description: 'Show the message editor button in messages',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'saveDirectMessage',
        description:
            'Save private channels to storage (disabling clears cached DMs)',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'overrideVoiceChannelBitrate',
        description:
            'Enable bitrate override for voice channels you join (/override bitrate)',
        type: VencordOptionType.boolean,
        defaultValue: false,
      ),
      VencordSettingDef(
        key: 'bitrateVoiceChannel',
        description: 'Default bitrate for voice channels (in Kbps, 6-5000)',
        type: VencordOptionType.number,
        defaultValue: 128,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'FakeNitro',
    description:
        'Allows sending cross-server, animated, or unboosted guild emojis even in channels that disallow external emojis, and renders FakeNitro emoji links inline.',
    authors: ['Arjix', 'D3SOX', 'Ven', 'Nuckyz'],
    tags: ['Emotes', 'Chat', 'Appearance'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'enableEmojiBypass',
        description:
            'Automatically send CDN emoji hyperlinks when channel lacks Use External Emojis permission or emoji is unavailable',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'emojiSize',
        description: 'Size of FakeNitro emojis when bypassed',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(label: '48px', value: 48, isDefault: true),
          VencordSelectOption(label: '64px', value: 64),
          VencordSelectOption(label: '96px', value: 96),
        ],
      ),
      VencordSettingDef(
        key: 'useHyperLinks',
        description: 'Use [name](url) markdown hyperlinks when bypassing emojis',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'transformEmojis',
        description: 'Render FakeNitro emoji links in chat as inline emojis',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'MessageLogger',
    description:
        'Temporarily logs deleted and edited messages so they remain visible in chat.',
    authors: ['Vendicated', 'Rushii'],
    tags: ['Chat', 'Utility'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'deleteStyle',
        description: 'The style of deleted messages',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(label: 'Red text', value: 'text', isDefault: true),
          VencordSelectOption(label: 'Red overlay', value: 'overlay'),
        ],
      ),
      VencordSettingDef(
        key: 'logDeletes',
        description: 'Whether to log deleted messages',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'logEdits',
        description: 'Whether to log edited messages',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'inlineEdits',
        description: 'Display edit history inline above edited message content',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'ignoreBots',
        description: 'Whether to ignore messages sent by bots',
        type: VencordOptionType.boolean,
        defaultValue: false,
      ),
      VencordSettingDef(
        key: 'ignoreSelf',
        description: 'Whether to ignore messages sent by yourself',
        type: VencordOptionType.boolean,
        defaultValue: false,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'ShowHiddenChannels',
    description:
        'Shows channels you lack permission to view with a lock icon and permission details.',
    authors: ['BigDuck', 'Ven', 'Nuckyz'],
    tags: ['Servers', 'Utility'],
    enabledByDefault: false,
    settings: [
      VencordSettingDef(
        key: 'showMode',
        description: 'The mode used to display hidden channels',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(
            label: 'Plain style with Lock Icon',
            value: 0,
            isDefault: true,
          ),
          VencordSelectOption(
            label: 'Muted style with hidden eye icon',
            value: 1,
          ),
        ],
      ),
    ],
  ),
  VencordPluginDef(
    name: 'NoReplyMention',
    description: 'Disables reply pings (@mention) by default when replying.',
    authors: ['DustyAngel47', 'rae', 'outfoxxed'],
    tags: ['Chat', 'Notifications'],
    enabledByDefault: false,
    settings: [
      VencordSettingDef(
        key: 'userList',
        description: 'Comma-separated list of user IDs to exempt or allow pings',
        type: VencordOptionType.string,
        defaultValue: '',
      ),
      VencordSettingDef(
        key: 'shouldPingListed',
        description: 'Behaviour for listed user IDs',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(
            label: 'Only ping the listed users',
            value: true,
            isDefault: true,
          ),
          VencordSelectOption(
            label: 'Do not ping the listed users',
            value: false,
          ),
        ],
      ),
    ],
  ),
  VencordPluginDef(
    name: 'SilentMessageToggle',
    description:
        'Adds a button to the chat bar to toggle sending a silent message (@silent / SUPPRESS_NOTIFICATIONS).',
    authors: ['Nuckyz', 'CatNoir'],
    tags: ['Chat', 'Utility'],
    enabledByDefault: false,
    settings: [
      VencordSettingDef(
        key: 'persistState',
        description: 'Persist silent message toggle state when changing channels',
        type: VencordOptionType.boolean,
        defaultValue: false,
      ),
      VencordSettingDef(
        key: 'autoDisable',
        description:
            'Automatically disable the silent message toggle after sending one',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'SilentTyping',
    description: 'Hides that you are typing from other users.',
    authors: ['Ven'],
    tags: ['Privacy', 'Chat'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'isEnabled',
        description: 'Suppress outgoing typing indicators globally',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'ViewRaw',
    description:
        'Copy and view the raw JSON data/content of any message, user, channel, or guild.',
    authors: ['KingFish', 'Ven', 'ImLvna'],
    tags: ['Chat', 'Developers'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'sortKeys',
        description: 'Alphabetically sort the keys of the raw JSON data',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'ViewIcons',
    description:
        'Makes avatars, banners, and server icons clickable in full resolution.',
    authors: ['Ven', 'TheKodeToad'],
    tags: ['Appearance', 'Utility'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'format',
        description: 'Preferred static image format',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(label: 'webp', value: 'webp', isDefault: true),
          VencordSelectOption(label: 'png', value: 'png'),
        ],
      ),
      VencordSettingDef(
        key: 'imgSize',
        description: 'Image size resolution',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(label: '1024', value: '1024', isDefault: true),
          VencordSelectOption(label: '2048', value: '2048'),
          VencordSelectOption(label: '4096', value: '4096'),
        ],
      ),
    ],
  ),
  VencordPluginDef(
    name: 'WhoReacted',
    description:
        'Allows inspecting all users who reacted to a message (long-press any reaction pill).',
    authors: ['Ven', 'KannaDev'],
    tags: ['Reactions', 'Chat'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'clickableAvatars',
        description: 'Tapping a reacting user opens their profile sheet',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'Translate',
    description:
        'Translate received messages inline and optionally auto-translate outgoing messages.',
    authors: ['Ven', 'AshtonMemer'],
    tags: ['Chat', 'Utility'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'receivedTarget',
        description: 'Target language code for received messages (e.g. zh-TW, en, ja)',
        type: VencordOptionType.string,
        defaultValue: 'zh-TW',
      ),
      VencordSettingDef(
        key: 'sentTarget',
        description: 'Target language code for outgoing auto-translate',
        type: VencordOptionType.string,
        defaultValue: 'en',
      ),
      VencordSettingDef(
        key: 'autoTranslate',
        description: 'Automatically translate outgoing messages before sending',
        type: VencordOptionType.boolean,
        defaultValue: false,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'SendTimestamps',
    description:
        'Send Discord dynamic timestamps via `HH:MM` backtick shortcuts or chat bar picker.',
    authors: ['Ven', 'Tyler', 'Grzesiek11'],
    tags: ['Chat', 'Commands'],
    enabledByDefault: false,
    settings: [
      VencordSettingDef(
        key: 'replaceMessageContents',
        description: 'Automatically convert `HH:MM` in outgoing messages to <t:UNIX:t>',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'TextReplace',
    description:
        'Replace text or regex patterns in your outgoing messages automatically.',
    authors: ['Ven'],
    tags: ['Chat', 'Customisation'],
    enabledByDefault: false,
  ),
  VencordPluginDef(
    name: 'AnonymiseFileNames',
    description: 'Anonymises uploaded attachment file names before sending.',
    authors: ['Ven'],
    tags: ['Privacy', 'Chat'],
    enabledByDefault: false,
    settings: [
      VencordSettingDef(
        key: 'method',
        description: 'Anonymisation method',
        type: VencordOptionType.select,
        options: [
          VencordSelectOption(
              label: 'Random Characters', value: 0, isDefault: true),
          VencordSelectOption(label: 'Unix Timestamp', value: 1),
        ],
      ),
    ],
  ),
  VencordPluginDef(
    name: 'RoleColorEverywhere',
    description:
        'Displays role colors in chat @mentions, voice channel member lists, and role group headers.',
    authors: ['Ven', 'Byron'],
    tags: ['Appearance', 'Roles'],
    enabledByDefault: true,
    settings: [
      VencordSettingDef(
        key: 'chatMentions',
        description: 'Color @user mentions in chat using their role color',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'voiceUsers',
        description: 'Color connected voice channel member names',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
      VencordSettingDef(
        key: 'roleHeaders',
        description: 'Color hoisted role headers in member list',
        type: VencordOptionType.boolean,
        defaultValue: true,
      ),
    ],
  ),
  VencordPluginDef(
    name: 'PermissionsViewer',
    description:
        'View detailed Discord permission flags for roles, channels, and guild members.',
    authors: ['Ven'],
    tags: ['Servers', 'Utility'],
    enabledByDefault: true,
  ),
  VencordPluginDef(
    name: 'RevealAllSpoilers',
    description: 'Automatically reveals all ||spoiler|| text in messages.',
    authors: ['Ven'],
    tags: ['Accessibility', 'Chat'],
    enabledByDefault: false,
  ),
  VencordPluginDef(
    name: 'AlwaysAnimate',
    description: 'Animates GIF emojis, avatars, and banners even in Eco mode.',
    authors: ['Ven'],
    tags: ['Appearance'],
    enabledByDefault: false,
  ),
  VencordPluginDef(
    name: 'MessageLatency',
    description:
        'Displays a subtle latency indicator next to message timestamps when send delay exceeds threshold.',
    authors: ['Ven'],
    tags: ['Chat', 'Developers'],
    enabledByDefault: false,
    settings: [
      VencordSettingDef(
        key: 'latencyThresholdSec',
        description: 'Minimum delay in seconds before showing badge',
        type: VencordOptionType.number,
        defaultValue: 2,
      ),
    ],
  ),
];

/// Manages Vencord Settings, Built-in & Custom Userplugins, Online Themes, QuickCSS,
/// and 1:1 JSON Settings Sync (`vencord-settings-backup.json`).
class VencordEngine {
  static const String _kVencordStateKey = 'dbc_vencord_state_v1';
  static const String _kVencordCustomPluginsKey = 'dbc_vencord_custom_plugins_v1';

  final VoidCallback onChanged;

  bool useQuickCss = true;
  String quickCss = '';
  List<String> themeLinks = <String>[];
  Map<String, Map<String, dynamic>> pluginSettings =
      <String, Map<String, dynamic>>{};
  List<VencordPluginDef> customPlugins = <VencordPluginDef>[];
  List<VencordTextRule> textReplaceRules = <VencordTextRule>[];

  final Map<String, String> _fetchedThemeCssCache = <String, String>{};

  VencordEngine({required this.onChanged});

  List<VencordPluginDef> get allPlugins => [
        ...kBuiltInVencordPlugins,
        ...customPlugins,
      ];

  VencordPluginDef? findPlugin(String name) {
    for (final p in kBuiltInVencordPlugins) {
      if (p.name == name) return p;
    }
    for (final p in customPlugins) {
      if (p.name == name) return p;
    }
    return null;
  }

  bool isPluginEnabled(String name) {
    final def = findPlugin(name);
    if (def == null) return false;
    if (def.required) return true;
    final map = pluginSettings[name];
    if (map != null && map['enabled'] is bool) {
      return map['enabled'] as bool;
    }
    return def.enabledByDefault;
  }

  T getSetting<T>(String pluginName, String key, T fallback) {
    final map = pluginSettings[pluginName];
    if (map != null && map.containsKey(key) && map[key] != null) {
      final raw = map[key];
      if (raw is T) return raw;
      if (T == int && raw is num) return raw.toInt() as T;
      if (T == double && raw is num) return raw.toDouble() as T;
      if (T == String) return raw.toString() as T;
      if (T == bool && raw is String) return (raw == 'true') as T;
    }
    final def = findPlugin(pluginName);
    if (def != null) {
      for (final s in def.settings) {
        if (s.key == key && s.resolvedDefault is T) {
          return s.resolvedDefault as T;
        }
      }
    }
    return fallback;
  }

  Future<void> load(SharedPreferences? prefs) async {
    if (prefs == null) {
      _ensureDefaults();
      return;
    }
    final customRaw = prefs.getString(_kVencordCustomPluginsKey);
    if (customRaw != null) {
      try {
        final list = jsonDecode(customRaw) as List<dynamic>;
        customPlugins = list
            .whereType<Map<String, dynamic>>()
            .map(VencordPluginDef.fromJson)
            .toList();
      } catch (_) {}
    }

    final raw = prefs.getString(_kVencordStateKey);
    if (raw != null) {
      try {
        final root = jsonDecode(raw) as Map<String, dynamic>;
        _applyParsedSettingsRoot(root);
      } catch (_) {}
    }
    _ensureDefaults();
    await refreshThemes();
  }

  void _ensureDefaults() {
    for (final p in allPlugins) {
      final map = pluginSettings.putIfAbsent(p.name, () => <String, dynamic>{});
      map['enabled'] = p.required
          ? true
          : (map['enabled'] as bool? ?? p.enabledByDefault);
      for (final s in p.settings) {
        map.putIfAbsent(s.key, () => s.resolvedDefault);
      }
    }
  }

  /// Bumped on every settings change (lets UI caches know plugins changed).
  int revision = 0;

  Future<void> save(SharedPreferences? prefs) async {
    revision++;
    if (prefs == null) return;
    await prefs.setString(_kVencordStateKey, exportVencordBackupJson(minify: true));
    await prefs.setString(
      _kVencordCustomPluginsKey,
      jsonEncode(customPlugins.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> setPluginEnabled(
    String pluginName,
    bool enabled,
    SharedPreferences? prefs,
  ) async {
    final def = findPlugin(pluginName);
    if (def == null || def.required) return;
    final map = pluginSettings.putIfAbsent(pluginName, () => <String, dynamic>{});
    map['enabled'] = enabled;
    await save(prefs);
    _recomputeThemeOverrides();
    onChanged();
  }

  Future<void> setPluginSetting(
    String pluginName,
    String key,
    Object? value,
    SharedPreferences? prefs,
  ) async {
    final map = pluginSettings.putIfAbsent(pluginName, () => <String, dynamic>{});
    map[key] = value;
    await save(prefs);
    onChanged();
  }

  Future<void> updateTextReplaceRules(
    List<VencordTextRule> nextRules,
    SharedPreferences? prefs,
  ) async {
    textReplaceRules = nextRules;
    final map =
        pluginSettings.putIfAbsent('TextReplace', () => <String, dynamic>{});
    map['stringRules'] =
        nextRules.where((r) => !r.isRegex).map((r) => r.toJson()).toList();
    map['regexRules'] =
        nextRules.where((r) => r.isRegex).map((r) => r.toJson()).toList();
    await save(prefs);
    onChanged();
  }

  Future<void> updateThemesAndQuickCss({
    required bool nextUseQuickCss,
    required String nextQuickCss,
    required List<String> nextThemeLinks,
    required SharedPreferences? prefs,
  }) async {
    useQuickCss = nextUseQuickCss;
    quickCss = nextQuickCss;
    themeLinks = nextThemeLinks
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    await save(prefs);
    await refreshThemes();
    onChanged();
  }

  /// Exports settings in exact desktop Vencord `exportSettings()` format
  /// (`Vencord/src/api/SettingsSync/offline.ts`).
  String exportVencordBackupJson({bool minify = false}) {
    final payload = {
      'settings': {
        'autoUpdate': true,
        'autoUpdateNotification': true,
        'useQuickCss': useQuickCss,
        'themeLinks': themeLinks,
        'enabledThemes': const <String>[],
        'plugins': pluginSettings,
      },
      'quickCss': quickCss,
    };
    return minify
        ? jsonEncode(payload)
        : const JsonEncoder.withIndent('    ').convert(payload);
  }

  /// Imports desktop Vencord / DiscordBotClient `vencord-settings-backup.json`.
  Future<void> importVencordBackupJson(
    String jsonStr,
    SharedPreferences? prefs,
  ) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic> ||
        !decoded.containsKey('settings') ||
        !decoded.containsKey('quickCss')) {
      throw const FormatException(
        'Invalid Settings. Expected Vencord settings JSON with "settings" and "quickCss".',
      );
    }
    _applyParsedSettingsRoot(decoded);
    _ensureDefaults();
    await save(prefs);
    await refreshThemes();
    onChanged();
  }

  void _applyParsedSettingsRoot(Map<String, dynamic> root) {
    final settings = root['settings'];
    if (settings is Map<String, dynamic>) {
      useQuickCss = settings['useQuickCss'] as bool? ?? true;
      final links = settings['themeLinks'];
      if (links is List<dynamic>) {
        themeLinks = links.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      final pluginsRaw = settings['plugins'];
      if (pluginsRaw is Map<String, dynamic>) {
        final parsedPlugins = <String, Map<String, dynamic>>{};
        pluginsRaw.forEach((k, v) {
          if (v is Map<String, dynamic>) {
            parsedPlugins[k] = Map<String, dynamic>.from(v);
          }
        });
        pluginSettings = parsedPlugins;

        // Hydrate TextReplace rules if present in Vencord backup
        final tr = parsedPlugins['TextReplace'];
        if (tr != null) {
          final loadedRules = <VencordTextRule>[];
          if (tr['stringRules'] is List<dynamic>) {
            for (final item in (tr['stringRules'] as List<dynamic>)) {
              if (item is Map<String, dynamic>) {
                final r = VencordTextRule.fromJson({...item, 'isRegex': false});
                if (r.find.isNotEmpty) loadedRules.add(r);
              }
            }
          }
          if (tr['regexRules'] is List<dynamic>) {
            for (final item in (tr['regexRules'] as List<dynamic>)) {
              if (item is Map<String, dynamic>) {
                final r = VencordTextRule.fromJson({...item, 'isRegex': true});
                if (r.find.isNotEmpty) loadedRules.add(r);
              }
            }
          }
          if (loadedRules.isNotEmpty) {
            textReplaceRules = loadedRules;
          }
        }
      }
    }
    if (root['quickCss'] is String) {
      quickCss = root['quickCss'] as String;
    }
  }

  // ==========================================================
  // Custom Vencord Userplugin Importer (URL or .ts/.tsx/.js/JSON)
  // ==========================================================
  static String normalizeGitHubRawUrl(String url) {
    var trimmed = url.trim();
    final blobMatch = RegExp(
      r'^https?://github\.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$',
    ).firstMatch(trimmed);
    if (blobMatch != null) {
      return 'https://raw.githubusercontent.com/${blobMatch.group(1)}/${blobMatch.group(2)}/${blobMatch.group(3)}/${blobMatch.group(4)}';
    }
    final treeMatch = RegExp(
      r'^https?://github\.com/([^/]+)/([^/]+)/tree/([^/]+)/(.+)$',
    ).firstMatch(trimmed);
    if (treeMatch != null) {
      return 'https://raw.githubusercontent.com/${treeMatch.group(1)}/${treeMatch.group(2)}/${treeMatch.group(3)}/${treeMatch.group(4)}/index.tsx';
    }
    return trimmed;
  }

  Future<VencordPluginDef> importCustomPluginFromUrl(
    String rawUrl,
    SharedPreferences? prefs,
  ) async {
    final normalized = normalizeGitHubRawUrl(rawUrl);
    http.Response res =
        await http.get(Uri.parse(normalized)).timeout(const Duration(seconds: 15));
    if (res.statusCode == 404 && normalized.endsWith('/index.tsx')) {
      final fallbackTs =
          normalized.substring(0, normalized.length - 4) + '.ts';
      res = await http
          .get(Uri.parse(fallbackTs))
          .timeout(const Duration(seconds: 15));
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw FormatException('無法下載插件原始碼 (HTTP ${res.statusCode})');
    }
    final source = utf8.decode(res.bodyBytes);
    return importCustomPluginFromSource(
      source,
      prefs,
      sourceUrl: normalized,
    );
  }

  Future<VencordPluginDef> importCustomPluginFromSource(
    String source,
    SharedPreferences? prefs, {
    String? sourceUrl,
  }) async {
    final trimmed = source.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('插件內容不可為空');
    }

    VencordPluginDef parsed;
    if (trimmed.startsWith('{')) {
      final json = jsonDecode(trimmed) as Map<String, dynamic>;
      parsed = VencordPluginDef.fromJson({
        ...json,
        if (sourceUrl != null) 'sourceUrl': sourceUrl,
      });
    } else {
      parsed = _parseTypeScriptDefinePlugin(trimmed, sourceUrl: sourceUrl);
    }

    customPlugins.removeWhere((p) => p.name == parsed.name);
    customPlugins.add(parsed);
    final map = pluginSettings.putIfAbsent(parsed.name, () => <String, dynamic>{});
    map['enabled'] = true;
    for (final s in parsed.settings) {
      map.putIfAbsent(s.key, () => s.resolvedDefault);
    }

    await save(prefs);
    _recomputeThemeOverrides();
    onChanged();
    return parsed;
  }

  Future<void> removeCustomPlugin(
    String pluginName,
    SharedPreferences? prefs,
  ) async {
    customPlugins.removeWhere((p) => p.name == pluginName);
    pluginSettings.remove(pluginName);
    await save(prefs);
    _recomputeThemeOverrides();
    onChanged();
  }

  /// Parses real Vencord `definePlugin({ ... })` & `definePluginSettings({ ... })` `.ts`/`.tsx`/`.js` files!
  VencordPluginDef _parseTypeScriptDefinePlugin(
    String code, {
    String? sourceUrl,
  }) {
    final defIdx = code.indexOf('definePlugin(');
    final searchScope = defIdx >= 0 ? code.substring(defIdx) : code;

    final nameMatch =
        RegExp(r'''name\s*:\s*["'`]([^"'`]+)["'`]''').firstMatch(searchScope);
    final descMatch = RegExp(
      r'''description\s*:\s*["'`]([^"'`]+)["'`]''',
    ).firstMatch(searchScope);

    final pluginName = nameMatch?.group(1)?.trim() ??
        (sourceUrl != null
            ? Uri.parse(sourceUrl)
                .pathSegments
                .where((s) => s.isNotEmpty && !s.startsWith('index.'))
                .lastOrNull ??
                'UserPlugin'
            : 'UserPlugin');
    final description =
        descMatch?.group(1)?.trim() ?? 'Imported Vencord userplugin';

    // Extract authors (Devs.X or { name: "..." })
    final authors = <String>[];
    final authorsBlock =
        RegExp(r'authors\s*:\s*\[([^\]]*)\]').firstMatch(searchScope)?.group(1);
    if (authorsBlock != null) {
      for (final m
          in RegExp(r'Devs\.([A-Za-z0-9_]+)').allMatches(authorsBlock)) {
        authors.add(m.group(1)!);
      }
      for (final m in RegExp(r'''name\s*:\s*["'`]([^"'`]+)["'`]''')
          .allMatches(authorsBlock)) {
        authors.add(m.group(1)!);
      }
    }

    // Extract definePluginSettings({ ... })
    final settings = <VencordSettingDef>[];
    final settingsStart = code.indexOf('definePluginSettings(');
    if (settingsStart >= 0) {
      final sub = code.substring(settingsStart);
      final entryRegex = RegExp(
        r'(\w+)\s*:\s*\{([^{}]*(?:\{[^{}]*\}[^{}]*)*)\}',
      );
      for (final m in entryRegex.allMatches(sub)) {
        final key = m.group(1)!;
        final body = m.group(2)!;
        if (!body.contains('OptionType.')) continue;
        final sDesc = RegExp(r'''description\s*:\s*["'`]([^"'`]+)["'`]''')
                .firstMatch(body)
                ?.group(1) ??
            key;
        if (body.contains('OptionType.BOOLEAN')) {
          final defBool =
              RegExp(r'default\s*:\s*(true|false)').firstMatch(body)?.group(1) ==
                  'true';
          settings.add(VencordSettingDef(
            key: key,
            description: sDesc,
            type: VencordOptionType.boolean,
            defaultValue: defBool,
          ));
        } else if (body.contains('OptionType.NUMBER') ||
            body.contains('OptionType.SLIDER')) {
          final numStr =
              RegExp(r'default\s*:\s*(-?\d+(?:\.\d+)?)').firstMatch(body)?.group(1);
          settings.add(VencordSettingDef(
            key: key,
            description: sDesc,
            type: VencordOptionType.number,
            defaultValue: num.tryParse(numStr ?? '0') ?? 0,
          ));
        } else if (body.contains('OptionType.STRING')) {
          final defStr = RegExp(r'''default\s*:\s*["'`]([^"'`]*)["'`]''')
                  .firstMatch(body)
                  ?.group(1) ??
              '';
          settings.add(VencordSettingDef(
            key: key,
            description: sDesc,
            type: VencordOptionType.string,
            defaultValue: defStr,
          ));
        }
      }
    }

    // Extract commands: [ { name: "...", description: "...", ... } ]
    final commands = <VencordPluginCommand>[];
    final cmdSection = RegExp(r'commands\s*:\s*\[([\s\S]*?)\]\s*,')
        .firstMatch(searchScope)
        ?.group(1);
    if (cmdSection != null) {
      final cmdObjRegex = RegExp(
        r'''name\s*:\s*["'`]([a-z0-9_-]+)["'`][\s\S]*?description\s*:\s*["'`]([^"'`]+)["'`]([\s\S]*?)(?=\{\s*name\s*:|$)''',
        caseSensitive: false,
      );
      for (final cm in cmdObjRegex.allMatches(cmdSection)) {
        final cName = cm.group(1)!;
        final cDesc = cm.group(2)!;
        final tail = cm.group(3) ?? '';
        final contentLiteral = RegExp(
          r'''content\s*:\s*["'`]([^"'`$]+)["'`]''',
        ).firstMatch(tail)?.group(1);
        commands.add(VencordPluginCommand(
          name: cName,
          description: cDesc,
          responseTemplate: contentLiteral,
          sendToChannel: !tail.contains('sendBotMessage'),
        ));
      }
    }

    // Extract simple .replace(/pattern/g, "replacement") in onBeforeMessageSend
    final preSendRules = <VencordTextRule>[];
    final preSendMatch = RegExp(
      r'onBeforeMessageSend\s*\([^)]*\)\s*\{([\s\S]*?)\n\s*\}',
    ).firstMatch(searchScope);
    if (preSendMatch != null) {
      final body = preSendMatch.group(1)!;
      for (final rm in RegExp(
        r'''\.replace\(\s*/([^/]+)/[gimsuy]*\s*,\s*["'`]([^"'`]*)["'`]\s*\)''',
      ).allMatches(body)) {
        preSendRules.add(VencordTextRule(
          find: rm.group(1)!,
          replace: rm.group(2)!,
          isRegex: true,
        ));
      }
      for (final sm in RegExp(
        r'''\.replaceAll\(\s*["'`]([^"'`]+)["'`]\s*,\s*["'`]([^"'`]*)["'`]\s*\)''',
      ).allMatches(body)) {
        preSendRules.add(VencordTextRule(
          find: sm.group(1)!,
          replace: sm.group(2)!,
          isRegex: false,
        ));
      }
    }

    // Extract inline CSS variables if present
    final cssVars = RegExp(r'--[a-zA-Z0-9_-]+\s*:\s*[^;\}]+;')
        .allMatches(code)
        .map((m) => m.group(0)!)
        .join('\n');

    return VencordPluginDef(
      name: pluginName,
      description: description,
      authors: authors.isEmpty ? const ['UserPlugin'] : authors,
      tags: const ['UserPlugin'],
      enabledByDefault: true,
      isCustom: true,
      sourceUrl: sourceUrl,
      settings: settings,
      commands: commands,
      preSendRules: preSendRules,
      managedStyle: cssVars.isNotEmpty ? ':root { $cssVars }' : null,
    );
  }

  // ==========================================================
  // Vencord Message Pre-Send Pipeline & Filename Anonymiser
  // ==========================================================
  String applyPreSendContentHooks(String input) {
    var out = input;

    // 1. SendTimestamps (`HH:MM` -> <t:UNIX:t>)
    if (isPluginEnabled('SendTimestamps') &&
        getSetting<bool>('SendTimestamps', 'replaceMessageContents', true)) {
      out = out.replaceAllMapped(
        RegExp(r'`(\d{1,2}):(\d{2})\s*(AM|PM)?`', caseSensitive: false),
        (m) {
          int hour = int.tryParse(m.group(1)!) ?? 0;
          final minute = int.tryParse(m.group(2)!) ?? 0;
          final ampm = m.group(3)?.toUpperCase();
          if (ampm == 'PM' && hour < 12) hour += 12;
          if (ampm == 'AM' && hour == 12) hour = 0;
          if (hour > 24 || minute > 59) return m.group(0)!;
          final now = DateTime.now();
          var dt = DateTime(now.year, now.month, now.day, hour, minute);
          if (now.isAfter(dt)) {
            dt = dt.add(const Duration(days: 1));
          }
          final unix = dt.millisecondsSinceEpoch ~/ 1000;
          return '<t:$unix:t>';
        },
      );
    }

    // 2. TextReplace plugin rules
    if (isPluginEnabled('TextReplace') && textReplaceRules.isNotEmpty) {
      out = _applyRulesList(out, textReplaceRules);
    }

    // 3. Enabled Custom Userplugins preSendRules
    for (final cp in customPlugins) {
      if (isPluginEnabled(cp.name) && cp.preSendRules.isNotEmpty) {
        out = _applyRulesList(out, cp.preSendRules);
      }
    }

    return out;
  }

  String _applyRulesList(String text, List<VencordTextRule> rules) {
    var current = text;
    for (final r in rules) {
      if (r.find.isEmpty) continue;
      if (r.onlyIfIncludes.isNotEmpty && !current.contains(r.onlyIfIncludes)) {
        continue;
      }
      if (r.isRegex) {
        try {
          current = current.replaceAll(RegExp(r.find), r.replace);
        } catch (_) {}
      } else {
        current = current.replaceAll(r.find, r.replace);
      }
    }
    return current;
  }

  String maybeAnonymiseFileName(String originalName) {
    if (!isPluginEnabled('AnonymiseFileNames')) return originalName;
    final dotIdx = originalName.lastIndexOf('.');
    final ext = dotIdx > 0 ? originalName.substring(dotIdx) : '';
    final method = getSetting<int>('AnonymiseFileNames', 'method', 0);
    if (method == 1) {
      return '${DateTime.now().millisecondsSinceEpoch}$ext';
    }
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rng = Random.secure();
    final rand =
        List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
    return '$rand$ext';
  }

  bool shouldMentionOnReply(String targetAuthorId) {
    if (!isPluginEnabled('NoReplyMention')) return true;
    final rawList = getSetting<String>('NoReplyMention', 'userList', '');
    final ids = rawList
        .split(RegExp(r'[,\s]+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final shouldPingListed =
        getSetting<bool>('NoReplyMention', 'shouldPingListed', true);
    final isListed = ids.contains(targetAuthorId);
    return shouldPingListed ? isListed : !isListed;
  }

  List<VencordPluginCommand> get enabledCustomCommands {
    final result = <VencordPluginCommand>[];
    for (final cp in customPlugins) {
      if (isPluginEnabled(cp.name)) {
        result.addAll(cp.commands);
      }
    }
    return result;
  }

  // ==========================================================
  // Vencord Online Themes & QuickCSS Variable Engine
  // ==========================================================
  Future<void> refreshThemes() async {
    for (final rawLink in themeLinks) {
      var link = rawLink.trim();
      if (link.startsWith('@light ')) continue;
      if (link.startsWith('@dark ')) {
        link = link.substring(6).trim();
      }
      link = normalizeGitHubRawUrl(link);
      if (!link.startsWith('http://') && !link.startsWith('https://')) {
        continue;
      }
      if (!_fetchedThemeCssCache.containsKey(link)) {
        try {
          final res = await http
              .get(Uri.parse(link))
              .timeout(const Duration(seconds: 10));
          if (res.statusCode >= 200 && res.statusCode < 300) {
            final body = utf8.decode(res.bodyBytes);
            _fetchedThemeCssCache[link] = body;
            // Follow one level of @import url("...") common in Vencord theme wrappers!
            final importMatch = RegExp(
              r'''@import\s+url\(\s*["']?(https?://[^"'\)\s]+)["']?\s*\)''',
            ).firstMatch(body);
            if (importMatch != null) {
              final subUrl = importMatch.group(1)!;
              final subRes = await http
                  .get(Uri.parse(subUrl))
                  .timeout(const Duration(seconds: 10));
              if (subRes.statusCode >= 200 && subRes.statusCode < 300) {
                _fetchedThemeCssCache[link] =
                    '${utf8.decode(subRes.bodyBytes)}\n$body';
              }
            }
          }
        } catch (_) {}
      }
    }
    _recomputeThemeOverrides();
  }

  void _recomputeThemeOverrides() {
    final chunks = <String>[];
    for (final rawLink in themeLinks) {
      var link = rawLink.trim();
      if (link.startsWith('@light ')) continue;
      if (link.startsWith('@dark ')) link = link.substring(6).trim();
      link = normalizeGitHubRawUrl(link);
      final css = _fetchedThemeCssCache[link];
      if (css != null) chunks.add(css);
    }
    for (final p in allPlugins) {
      if (isPluginEnabled(p.name) &&
          p.managedStyle != null &&
          p.managedStyle!.isNotEmpty) {
        chunks.add(p.managedStyle!);
      }
    }
    if (useQuickCss && quickCss.trim().isNotEmpty) {
      chunks.add(quickCss);
    }

    if (chunks.isEmpty) {
      DiscordPalette.activeThemeOverrides = null;
      return;
    }

    final vars = _parseCssVariables(chunks.join('\n'));
    if (vars.isEmpty) {
      DiscordPalette.activeThemeOverrides = null;
      return;
    }

    Color? pick(List<String> names) {
      for (final n in names) {
        final val = vars[n];
        if (val != null) {
          final c = _parseCssColor(val, vars, 0);
          if (c != null) return c;
        }
      }
      return null;
    }

    final bgPrimary =
        pick(['--background-primary', '--bg-overlay-chat', '--main-color']);
    final bgSecondary =
        pick(['--background-secondary', '--bg-base-secondary']);
    final bgTertiary =
        pick(['--background-tertiary', '--bg-base-tertiary']);
    final bgFloating =
        pick(['--background-floating', '--background-secondary-alt']);
    final brand = pick([
      '--brand-experiment',
      '--brand-500',
      '--accent-color',
      '--main-accent'
    ]);

    DiscordPalette.activeThemeOverrides = VencordThemeOverrides(
      chatBg: bgPrimary,
      sidebarBg: bgSecondary,
      railBg: bgTertiary,
      profileBg: bgFloating ?? bgTertiary,
      bottomBarBg: bgFloating ?? bgSecondary,
      cardBg: pick(['--background-secondary-alt', '--card-secondary-bg']) ??
          bgSecondary,
      elevatedBg: pick(['--background-modifier-accent']) ?? bgTertiary,
      selectedChannelBg: pick(['--background-modifier-selected']),
      inputBg: pick(['--channeltextarea-background']) ?? bgSecondary,
      border: pick(['--background-modifier-accent']),
      textPrimary: pick(['--text-normal', '--header-primary']),
      textSecondary: pick(['--header-secondary', '--interactive-normal']),
      textMuted: pick(['--text-muted', '--channels-default']),
      brand: brand,
    );
  }

  static Map<String, String> _parseCssVariables(String css) {
    final noComments = css.replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '');
    final map = <String, String>{};
    final propRegex = RegExp(r'(--[a-zA-Z0-9_-]+)\s*:\s*([^;\}]+)');
    for (final m in propRegex.allMatches(noComments)) {
      map[m.group(1)!.trim()] =
          m.group(2)!.replaceAll('!important', '').trim();
    }
    return map;
  }

  static Color? _parseCssColor(
    String raw,
    Map<String, String> vars,
    int depth,
  ) {
    if (depth > 4) return null;
    final v = raw.trim();
    final varMatch =
        RegExp(r'^var\(\s*(--[a-zA-Z0-9_-]+)(?:\s*,\s*([^\)]+))?\)$')
            .firstMatch(v);
    if (varMatch != null) {
      final ref = vars[varMatch.group(1)!] ?? varMatch.group(2);
      if (ref == null) return null;
      return _parseCssColor(ref, vars, depth + 1);
    }

    if (v.startsWith('#')) {
      final hex = v.substring(1);
      if (hex.length == 3) {
        final r = hex[0] * 2;
        final g = hex[1] * 2;
        final b = hex[2] * 2;
        return Color(int.parse('FF$r$g$b', radix: 16));
      }
      if (hex.length == 6) {
        final parsed = int.tryParse('FF$hex', radix: 16);
        return parsed != null ? Color(parsed) : null;
      }
      if (hex.length == 8) {
        final rrggbb = hex.substring(0, 6);
        final aa = hex.substring(6, 8);
        final parsed = int.tryParse('$aa$rrggbb', radix: 16);
        return parsed != null ? Color(parsed) : null;
      }
    }

    final rgbMatch = RegExp(
      r'^rgba?\(\s*(\d{1,3})\s*[,\s]\s*(\d{1,3})\s*[,\s]\s*(\d{1,3})(?:\s*[,/]\s*([0-9.]+))?\s*\)$',
    ).firstMatch(v);
    if (rgbMatch != null) {
      final r = (int.tryParse(rgbMatch.group(1)!) ?? 0).clamp(0, 255);
      final g = (int.tryParse(rgbMatch.group(2)!) ?? 0).clamp(0, 255);
      final b = (int.tryParse(rgbMatch.group(3)!) ?? 0).clamp(0, 255);
      final a = rgbMatch.group(4) != null
          ? ((double.tryParse(rgbMatch.group(4)!) ?? 1.0).clamp(0.0, 1.0) * 255)
              .round()
          : 255;
      return Color.fromARGB(a, r, g, b);
    }

    final hslMatch = RegExp(
      r'^hsla?\(\s*([0-9.]+)(?:deg)?\s*[,\s]\s*([0-9.]+)%\s*[,\s]\s*([0-9.]+)%(?:\s*[,/]\s*([0-9.]+))?\s*\)$',
    ).firstMatch(v);
    if (hslMatch != null) {
      final h = (double.tryParse(hslMatch.group(1)!) ?? 0) % 360;
      final s = ((double.tryParse(hslMatch.group(2)!) ?? 0) / 100.0).clamp(0.0, 1.0);
      final l = ((double.tryParse(hslMatch.group(3)!) ?? 0) / 100.0).clamp(0.0, 1.0);
      final a = hslMatch.group(4) != null
          ? (double.tryParse(hslMatch.group(4)!) ?? 1.0).clamp(0.0, 1.0)
          : 1.0;
      return HSLColor.fromAHSL(a, h, s, l).toColor();
    }

    return null;
  }
}
