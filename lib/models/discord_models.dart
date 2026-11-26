import 'dart:convert';

class EcoSettings {
  final bool oledBlackMode;
  final bool ecoPowerSaving;
  final int backgroundSuspendSeconds;
  final bool enableMessageContentIntent;
  final bool enableMembersIntent;
  final bool enablePresenceIntent;
  final bool silentTyping;
  final bool showPerformanceHud;

  const EcoSettings({
    this.oledBlackMode = true,
    this.ecoPowerSaving = true,
    this.backgroundSuspendSeconds = 25,
    this.enableMessageContentIntent = true,
    this.enableMembersIntent = false,
    this.enablePresenceIntent = false,
    this.silentTyping = true,
    this.showPerformanceHud = false,
  });

  /// Computes the Discord Gateway v10 Intents bitmask.
  /// By excluding GUILD_PRESENCES (1 << 8) & TYPING in Eco mode, WebSocket
  /// traffic & radio wakeups drop by up to 80% in large servers.
  int computeIntentsBitmask({bool stripPrivileged = false}) {
    int mask = 0;
    mask |= (1 << 0); // GUILDS
    mask |= (1 << 9); // GUILD_MESSAGES
    mask |= (1 << 10); // GUILD_MESSAGE_REACTIONS
    mask |= (1 << 12); // DIRECT_MESSAGES
    mask |= (1 << 13); // DIRECT_MESSAGE_REACTIONS

    if (!ecoPowerSaving) {
      mask |= (1 << 11); // GUILD_MESSAGE_TYPING
      mask |= (1 << 14); // DIRECT_MESSAGE_TYPING
    }

    if (!stripPrivileged) {
      if (enableMembersIntent) {
        mask |= (1 << 1); // GUILD_MEMBERS (Privileged)
      }
      if (enablePresenceIntent && !ecoPowerSaving) {
        mask |= (1 << 8); // GUILD_PRESENCES (Privileged - heavy battery drain)
      }
      if (enableMessageContentIntent) {
        mask |= (1 << 15); // MESSAGE_CONTENT (Privileged)
      }
    }
    return mask;
  }

  int get avatarSize => ecoPowerSaving ? 64 : 128;
  int get attachmentPreviewWidth => ecoPowerSaving ? 400 : 720;

  EcoSettings copyWith({
    bool? oledBlackMode,
    bool? ecoPowerSaving,
    int? backgroundSuspendSeconds,
    bool? enableMessageContentIntent,
    bool? enableMembersIntent,
    bool? enablePresenceIntent,
    bool? silentTyping,
    bool? showPerformanceHud,
  }) {
    return EcoSettings(
      oledBlackMode: oledBlackMode ?? this.oledBlackMode,
      ecoPowerSaving: ecoPowerSaving ?? this.ecoPowerSaving,
      backgroundSuspendSeconds:
          backgroundSuspendSeconds ?? this.backgroundSuspendSeconds,
      enableMessageContentIntent:
          enableMessageContentIntent ?? this.enableMessageContentIntent,
      enableMembersIntent: enableMembersIntent ?? this.enableMembersIntent,
      enablePresenceIntent: enablePresenceIntent ?? this.enablePresenceIntent,
      silentTyping: silentTyping ?? this.silentTyping,
      showPerformanceHud: showPerformanceHud ?? this.showPerformanceHud,
    );
  }

  Map<String, dynamic> toJson() => {
        'oledBlackMode': oledBlackMode,
        'ecoPowerSaving': ecoPowerSaving,
        'backgroundSuspendSeconds': backgroundSuspendSeconds,
        'enableMessageContentIntent': enableMessageContentIntent,
        'enableMembersIntent': enableMembersIntent,
        'enablePresenceIntent': enablePresenceIntent,
        'silentTyping': silentTyping,
        'showPerformanceHud': showPerformanceHud,
      };

  factory EcoSettings.fromJson(Map<String, dynamic> json) {
    return EcoSettings(
      oledBlackMode: json['oledBlackMode'] as bool? ?? true,
      ecoPowerSaving: json['ecoPowerSaving'] as bool? ?? true,
      backgroundSuspendSeconds: json['backgroundSuspendSeconds'] as int? ?? 25,
      enableMessageContentIntent:
          json['enableMessageContentIntent'] as bool? ?? true,
      enableMembersIntent: json['enableMembersIntent'] as bool? ?? false,
      enablePresenceIntent: json['enablePresenceIntent'] as bool? ?? false,
      silentTyping: json['silentTyping'] as bool? ?? true,
      showPerformanceHud: json['showPerformanceHud'] as bool? ?? false,
    );
  }
}

class BotAccount {
  final String token;
  final String id;
  final String username;
  final String discriminator;
  final String? globalName;
  final String? avatar;
  final String? banner;
  final int? accentColor;
  final String? bio;
  final String? applicationId;

  const BotAccount({
    required this.token,
    required this.id,
    required this.username,
    required this.discriminator,
    this.globalName,
    this.avatar,
    this.banner,
    this.accentColor,
    this.bio,
    this.applicationId,
  });

  String get displayName =>
      (globalName != null && globalName!.isNotEmpty) ? globalName! : username;

  String get tag =>
      (discriminator == '0' || discriminator.isEmpty)
          ? username
          : '$username#$discriminator';

  String avatarUrl({int size = 64}) {
    if (avatar == null || avatar!.isEmpty) {
      final index = (int.tryParse(id) ?? 0) % 5;
      return 'https://cdn.discordapp.com/embed/avatars/$index.png';
    }
    return 'https://cdn.discordapp.com/avatars/$id/$avatar.webp?size=$size';
  }

  String? bannerUrl({int size = 512}) {
    if (banner == null || banner!.isEmpty) return null;
    return 'https://cdn.discordapp.com/banners/$id/$banner.webp?size=$size';
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'id': id,
        'username': username,
        'discriminator': discriminator,
        'globalName': globalName,
        'avatar': avatar,
        'banner': banner,
        'accentColor': accentColor,
        'bio': bio,
        'applicationId': applicationId,
      };

  factory BotAccount.fromJson(Map<String, dynamic> json) {
    return BotAccount(
      token: json['token'] as String? ?? '',
      id: json['id']?.toString() ?? '',
      username: json['username'] as String? ?? 'Bot',
      discriminator: json['discriminator']?.toString() ?? '0',
      globalName: json['globalName'] as String?,
      avatar: json['avatar'] as String?,
      banner: json['banner'] as String?,
      accentColor: json['accentColor'] as int?,
      bio: json['bio'] as String?,
      applicationId: json['applicationId']?.toString(),
    );
  }
}

class DiscordUser {
  final String id;
  final String username;
  final String discriminator;
  final String? globalName;
  final String? avatar;
  final bool bot;

  const DiscordUser({
    required this.id,
    required this.username,
    this.discriminator = '0',
    this.globalName,
    this.avatar,
    this.bot = false,
  });

  String get displayName =>
      (globalName != null && globalName!.isNotEmpty) ? globalName! : username;

  String avatarUrl({int size = 64}) {
    if (avatar == null || avatar!.isEmpty) {
      final idx = ((BigInt.tryParse(id) ?? BigInt.zero) >> 22).toInt().abs() % 6;
      return 'https://cdn.discordapp.com/embed/avatars/$idx.png';
    }
    return 'https://cdn.discordapp.com/avatars/$id/$avatar.webp?size=$size';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'discriminator': discriminator,
        'global_name': globalName,
        'avatar': avatar,
        'bot': bot,
      };

  factory DiscordUser.fromJson(Map<String, dynamic> json) {
    return DiscordUser(
      id: json['id']?.toString() ?? '0',
      username: json['username'] as String? ?? 'Unknown',
      discriminator: json['discriminator']?.toString() ?? '0',
      globalName: json['global_name'] as String?,
      avatar: json['avatar'] as String?,
      bot: json['bot'] as bool? ?? false,
    );
  }
}

class DiscordMember {
  final DiscordUser user;
  final String? nick;
  final List<String> roleIds;
  final String? joinedAt;

  const DiscordMember({
    required this.user,
    this.nick,
    this.roleIds = const [],
    this.joinedAt,
  });

  String get effectiveName =>
      (nick != null && nick!.isNotEmpty) ? nick! : user.displayName;

  factory DiscordMember.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] as Map<String, dynamic>? ?? const {};
    final rolesRaw = json['roles'] as List<dynamic>? ?? const [];
    return DiscordMember(
      user: DiscordUser.fromJson(userMap),
      nick: json['nick'] as String?,
      roleIds: rolesRaw.map((e) => e.toString()).toList(),
      joinedAt: json['joined_at'] as String?,
    );
  }
}

class DiscordRole {
  final String id;
  final String name;
  final int color;
  final int position;
  final BigInt permissions;
  final bool hoist;
  final bool managed;

  const DiscordRole({
    required this.id,
    required this.name,
    required this.color,
    required this.position,
    required this.permissions,
    this.hoist = false,
    this.managed = false,
  });

  factory DiscordRole.fromJson(Map<String, dynamic> json) {
    return DiscordRole(
      id: json['id']?.toString() ?? '0',
      name: json['name'] as String? ?? 'role',
      color: json['color'] as int? ?? 0,
      position: json['position'] as int? ?? 0,
      permissions:
          BigInt.tryParse(json['permissions']?.toString() ?? '0') ?? BigInt.zero,
      hoist: json['hoist'] as bool? ?? false,
      managed: json['managed'] as bool? ?? false,
    );
  }
}

class PermissionOverwrite {
  final String id;
  final int type; // 0 = role, 1 = member
  final BigInt allow;
  final BigInt deny;

  const PermissionOverwrite({
    required this.id,
    required this.type,
    required this.allow,
    required this.deny,
  });

  factory PermissionOverwrite.fromJson(Map<String, dynamic> json) {
    return PermissionOverwrite(
      id: json['id']?.toString() ?? '0',
      type: int.tryParse(json['type']?.toString() ?? '0') ?? 0,
      allow: BigInt.tryParse(json['allow']?.toString() ?? '0') ?? BigInt.zero,
      deny: BigInt.tryParse(json['deny']?.toString() ?? '0') ?? BigInt.zero,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'allow': allow.toString(),
        'deny': deny.toString(),
      };
}

class DiscordPermissions {
  static final BigInt kickMembers = BigInt.one << 1;
  static final BigInt banMembers = BigInt.one << 2;
  static final BigInt administrator = BigInt.one << 3;
  static final BigInt manageChannels = BigInt.one << 4;
  static final BigInt manageGuild = BigInt.one << 5;
  static final BigInt addReactions = BigInt.one << 6;
  static final BigInt viewAuditLog = BigInt.one << 7;
  static final BigInt viewChannel = BigInt.one << 10;
  static final BigInt sendMessages = BigInt.one << 11;
  static final BigInt manageMessages = BigInt.one << 13;
  static final BigInt embedLinks = BigInt.one << 14;
  static final BigInt attachFiles = BigInt.one << 15;
  static final BigInt readMessageHistory = BigInt.one << 16;
  static final BigInt manageWebhooks = BigInt.one << 29;
  static final BigInt sendMessagesInThreads = BigInt.one << 38;
  static final BigInt all = (BigInt.one << 53) - BigInt.one;

  static BigInt computeChannelPermissions({
    required DiscordGuild guild,
    required DiscordChannel channel,
    required String botUserId,
    required List<String> botRoleIds,
  }) {
    if (guild.ownerId == botUserId) return all;

    BigInt basePerms = guild.roles[guild.id]?.permissions ?? BigInt.zero;
    for (final roleId in botRoleIds) {
      final role = guild.roles[roleId];
      if (role != null) {
        basePerms |= role.permissions;
      }
    }

    if ((basePerms & administrator) == administrator) {
      return all;
    }

    BigInt perms = basePerms;
    // 1. @everyone overwrite
    for (final ow in channel.permissionOverwrites) {
      if (ow.id == guild.id) {
        perms &= ~ow.deny;
        perms |= ow.allow;
      }
    }
    // 2. Role overwrites
    BigInt allowRoles = BigInt.zero;
    BigInt denyRoles = BigInt.zero;
    for (final ow in channel.permissionOverwrites) {
      if (ow.type == 0 && botRoleIds.contains(ow.id)) {
        allowRoles |= ow.allow;
        denyRoles |= ow.deny;
      }
    }
    perms &= ~denyRoles;
    perms |= allowRoles;

    // 3. Member-specific overwrite
    for (final ow in channel.permissionOverwrites) {
      if (ow.type == 1 && ow.id == botUserId) {
        perms &= ~ow.deny;
        perms |= ow.allow;
      }
    }
    return perms;
  }

  static bool has(BigInt perms, BigInt flag) => (perms & flag) == flag;
}

class DiscordChannel {
  final String id;
  final String? guildId;
  final String name;
  final int type;
  final int position;
  final String? parentId;
  final String? topic;
  final String? lastMessageId;
  final int rateLimitPerUser;
  final List<PermissionOverwrite> permissionOverwrites;
  final List<DiscordUser> recipients;

  const DiscordChannel({
    required this.id,
    this.guildId,
    required this.name,
    required this.type,
    this.position = 0,
    this.parentId,
    this.topic,
    this.lastMessageId,
    this.rateLimitPerUser = 0,
    this.permissionOverwrites = const [],
    this.recipients = const [],
  });

  bool get isCategory => type == 4;
  bool get isDm => type == 1 || type == 3;
  bool get isVoice => type == 2 || type == 13;
  bool get isMessageable =>
      type == 0 ||
      type == 1 ||
      type == 2 ||
      type == 3 ||
      type == 5 ||
      type == 10 ||
      type == 11 ||
      type == 12;

  String get displayTitle {
    if (isDm && recipients.isNotEmpty) {
      return recipients.map((u) => u.displayName).join(', ');
    }
    return name;
  }

  DiscordUser? get dmRecipient => recipients.isNotEmpty ? recipients.first : null;

  DiscordChannel copyWith({
    String? name,
    String? topic,
    String? lastMessageId,
    int? position,
    String? parentId,
    int? rateLimitPerUser,
    List<PermissionOverwrite>? permissionOverwrites,
    List<DiscordUser>? recipients,
  }) {
    return DiscordChannel(
      id: id,
      guildId: guildId,
      name: name ?? this.name,
      type: type,
      position: position ?? this.position,
      parentId: parentId ?? this.parentId,
      topic: topic ?? this.topic,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      rateLimitPerUser: rateLimitPerUser ?? this.rateLimitPerUser,
      permissionOverwrites: permissionOverwrites ?? this.permissionOverwrites,
      recipients: recipients ?? this.recipients,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'guild_id': guildId,
        'name': name,
        'type': type,
        'position': position,
        'parent_id': parentId,
        'topic': topic,
        'last_message_id': lastMessageId,
        'rate_limit_per_user': rateLimitPerUser,
        'permission_overwrites':
            permissionOverwrites.map((e) => e.toJson()).toList(),
        'recipients': recipients.map((e) => e.toJson()).toList(),
      };

  factory DiscordChannel.fromJson(Map<String, dynamic> json, {String? guildId}) {
    final owRaw = json['permission_overwrites'] as List<dynamic>? ?? const [];
    final recRaw = json['recipients'] as List<dynamic>? ?? const [];
    final recipients = recRaw
        .whereType<Map<String, dynamic>>()
        .map(DiscordUser.fromJson)
        .toList();
    String fallbackName = json['name'] as String? ?? '';
    if (fallbackName.isEmpty && recipients.isNotEmpty) {
      fallbackName = recipients.first.displayName;
    }
    if (fallbackName.isEmpty) {
      fallbackName = 'channel-${json['id']}';
    }
    return DiscordChannel(
      id: json['id']?.toString() ?? '0',
      guildId: json['guild_id']?.toString() ?? guildId,
      name: fallbackName,
      type: json['type'] as int? ?? 0,
      position: json['position'] as int? ?? 0,
      parentId: json['parent_id']?.toString(),
      topic: json['topic'] as String?,
      lastMessageId: json['last_message_id']?.toString(),
      rateLimitPerUser: json['rate_limit_per_user'] as int? ?? 0,
      permissionOverwrites: owRaw
          .whereType<Map<String, dynamic>>()
          .map(PermissionOverwrite.fromJson)
          .toList(),
      recipients: recipients,
    );
  }
}

class DiscordEmoji {
  final String? id;
  final String name;
  final bool animated;

  const DiscordEmoji({
    this.id,
    required this.name,
    this.animated = false,
  });

  String get apiIdentifier =>
      (id != null && id!.isNotEmpty) ? '$name:$id' : name;

  String? imageUrl({int size = 48, bool allowAnimated = false}) {
    if (id == null || id!.isEmpty) return null;
    final ext = (animated && allowAnimated) ? 'gif' : 'webp';
    return 'https://cdn.discordapp.com/emojis/$id.$ext?size=$size';
  }

  factory DiscordEmoji.fromJson(Map<String, dynamic> json) {
    return DiscordEmoji(
      id: json['id']?.toString(),
      name: json['name'] as String? ?? '❓',
      animated: json['animated'] as bool? ?? false,
    );
  }
}

class DiscordGuild {
  final String id;
  final String name;
  final String? icon;
  final String? ownerId;
  final int? memberCount;
  final Map<String, DiscordRole> roles;
  final List<DiscordChannel> channels;
  final List<DiscordEmoji> emojis;
  final List<String> botRoleIds;
  final bool channelsLoaded;

  const DiscordGuild({
    required this.id,
    required this.name,
    this.icon,
    this.ownerId,
    this.memberCount,
    this.roles = const {},
    this.channels = const [],
    this.emojis = const [],
    this.botRoleIds = const [],
    this.channelsLoaded = false,
  });

  String? iconUrl({int size = 64}) {
    if (icon == null || icon!.isEmpty) return null;
    return 'https://cdn.discordapp.com/icons/$id/$icon.webp?size=$size';
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(1, 2));
    }
    return words.take(3).map((w) => w.isNotEmpty ? w[0] : '').join();
  }

  DiscordGuild copyWith({
    String? name,
    String? icon,
    String? ownerId,
    int? memberCount,
    Map<String, DiscordRole>? roles,
    List<DiscordChannel>? channels,
    List<DiscordEmoji>? emojis,
    List<String>? botRoleIds,
    bool? channelsLoaded,
  }) {
    return DiscordGuild(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      ownerId: ownerId ?? this.ownerId,
      memberCount: memberCount ?? this.memberCount,
      roles: roles ?? this.roles,
      channels: channels ?? this.channels,
      emojis: emojis ?? this.emojis,
      botRoleIds: botRoleIds ?? this.botRoleIds,
      channelsLoaded: channelsLoaded ?? this.channelsLoaded,
    );
  }

  factory DiscordGuild.fromJson(
    Map<String, dynamic> json, {
    String? currentBotUserId,
  }) {
    final guildId = json['id']?.toString() ?? '0';
    final rolesRaw = json['roles'] as List<dynamic>? ?? const [];
    final rolesMap = <String, DiscordRole>{};
    for (final r in rolesRaw) {
      if (r is Map<String, dynamic>) {
        final role = DiscordRole.fromJson(r);
        rolesMap[role.id] = role;
      }
    }

    final channelsRaw = json['channels'] as List<dynamic>?;
    final parsedChannels = <DiscordChannel>[];
    if (channelsRaw != null) {
      for (final c in channelsRaw) {
        if (c is Map<String, dynamic>) {
          parsedChannels.add(DiscordChannel.fromJson(c, guildId: guildId));
        }
      }
    }
    // Also merge active threads if sent in GUILD_CREATE
    final threadsRaw = json['threads'] as List<dynamic>?;
    if (threadsRaw != null) {
      for (final t in threadsRaw) {
        if (t is Map<String, dynamic>) {
          parsedChannels.add(DiscordChannel.fromJson(t, guildId: guildId));
        }
      }
    }

    final emojisRaw = json['emojis'] as List<dynamic>? ?? const [];
    final parsedEmojis = emojisRaw
        .whereType<Map<String, dynamic>>()
        .map(DiscordEmoji.fromJson)
        .toList();

    List<String> botRoles = const [];
    if (currentBotUserId != null && json['members'] is List<dynamic>) {
      for (final m in (json['members'] as List<dynamic>)) {
        if (m is Map<String, dynamic>) {
          final u = m['user'] as Map<String, dynamic>?;
          if (u != null && u['id']?.toString() == currentBotUserId) {
            final rList = m['roles'] as List<dynamic>? ?? const [];
            botRoles = rList.map((e) => e.toString()).toList();
            break;
          }
        }
      }
    }

    return DiscordGuild(
      id: guildId,
      name: json['name'] as String? ?? 'Server',
      icon: json['icon'] as String?,
      ownerId: json['owner_id']?.toString(),
      memberCount:
          json['member_count'] as int? ?? json['approximate_member_count'] as int?,
      roles: rolesMap,
      channels: parsedChannels,
      emojis: parsedEmojis,
      botRoleIds: botRoles,
      channelsLoaded: channelsRaw != null,
    );
  }
}

class DiscordAttachment {
  final String id;
  final String filename;
  final int size;
  final String url;
  final String proxyUrl;
  final String? contentType;
  final int? width;
  final int? height;

  const DiscordAttachment({
    required this.id,
    required this.filename,
    required this.size,
    required this.url,
    required this.proxyUrl,
    this.contentType,
    this.width,
    this.height,
  });

  bool get isImage {
    if (contentType != null && contentType!.startsWith('image/')) return true;
    final lower = filename.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String previewUrl({int maxWidth = 480}) {
    if (!isImage) return url;
    final sep = proxyUrl.contains('?') ? '&' : '?';
    return '$proxyUrl${sep}width=$maxWidth&format=webp';
  }

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  factory DiscordAttachment.fromJson(Map<String, dynamic> json) {
    return DiscordAttachment(
      id: json['id']?.toString() ?? '0',
      filename: json['filename'] as String? ?? 'file',
      size: json['size'] as int? ?? 0,
      url: json['url'] as String? ?? '',
      proxyUrl: json['proxy_url'] as String? ?? (json['url'] as String? ?? ''),
      contentType: json['content_type'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class DiscordEmbedField {
  final String name;
  final String value;
  final bool inline;

  const DiscordEmbedField({
    required this.name,
    required this.value,
    this.inline = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'value': value,
        'inline': inline,
      };

  factory DiscordEmbedField.fromJson(Map<String, dynamic> json) {
    return DiscordEmbedField(
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
      inline: json['inline'] as bool? ?? false,
    );
  }
}

class DiscordEmbed {
  final String? title;
  final String? description;
  final String? url;
  final int? color;
  final String? authorName;
  final String? authorIconUrl;
  final String? footerText;
  final String? footerIconUrl;
  final String? imageUrl;
  final String? thumbnailUrl;
  final String? timestamp;
  final List<DiscordEmbedField> fields;

  const DiscordEmbed({
    this.title,
    this.description,
    this.url,
    this.color,
    this.authorName,
    this.authorIconUrl,
    this.footerText,
    this.footerIconUrl,
    this.imageUrl,
    this.thumbnailUrl,
    this.timestamp,
    this.fields = const [],
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (title != null && title!.isNotEmpty) map['title'] = title;
    if (description != null && description!.isNotEmpty) {
      map['description'] = description;
    }
    if (url != null && url!.isNotEmpty) map['url'] = url;
    if (color != null) map['color'] = color;
    if (authorName != null && authorName!.isNotEmpty) {
      map['author'] = {
        'name': authorName,
        if (authorIconUrl != null && authorIconUrl!.isNotEmpty)
          'icon_url': authorIconUrl,
      };
    }
    if (footerText != null && footerText!.isNotEmpty) {
      map['footer'] = {
        'text': footerText,
        if (footerIconUrl != null && footerIconUrl!.isNotEmpty)
          'icon_url': footerIconUrl,
      };
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      map['image'] = {'url': imageUrl};
    }
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      map['thumbnail'] = {'url': thumbnailUrl};
    }
    if (timestamp != null) map['timestamp'] = timestamp;
    if (fields.isNotEmpty) {
      map['fields'] = fields.map((f) => f.toJson()).toList();
    }
    return map;
  }

  factory DiscordEmbed.fromJson(Map<String, dynamic> json) {
    final author = json['author'] as Map<String, dynamic>?;
    final footer = json['footer'] as Map<String, dynamic>?;
    final image = json['image'] as Map<String, dynamic>?;
    final thumb = json['thumbnail'] as Map<String, dynamic>?;
    final fieldsRaw = json['fields'] as List<dynamic>? ?? const [];

    return DiscordEmbed(
      title: json['title'] as String?,
      description: json['description'] as String?,
      url: json['url'] as String?,
      color: json['color'] as int?,
      authorName: author?['name'] as String?,
      authorIconUrl: author?['proxy_icon_url'] as String? ??
          author?['icon_url'] as String?,
      footerText: footer?['text'] as String?,
      footerIconUrl: footer?['proxy_icon_url'] as String? ??
          footer?['icon_url'] as String?,
      imageUrl: image?['proxy_url'] as String? ?? image?['url'] as String?,
      thumbnailUrl: thumb?['proxy_url'] as String? ?? thumb?['url'] as String?,
      timestamp: json['timestamp'] as String?,
      fields: fieldsRaw
          .whereType<Map<String, dynamic>>()
          .map(DiscordEmbedField.fromJson)
          .toList(),
    );
  }
}

class DiscordReaction {
  final DiscordEmoji emoji;
  final int count;
  final bool me;

  const DiscordReaction({
    required this.emoji,
    required this.count,
    required this.me,
  });

  DiscordReaction copyWith({int? count, bool? me}) {
    return DiscordReaction(
      emoji: emoji,
      count: count ?? this.count,
      me: me ?? this.me,
    );
  }

  factory DiscordReaction.fromJson(Map<String, dynamic> json) {
    return DiscordReaction(
      emoji: DiscordEmoji.fromJson(
          json['emoji'] as Map<String, dynamic>? ?? const {}),
      count: json['count'] as int? ?? 1,
      me: json['me'] as bool? ?? false,
    );
  }
}

class DiscordComponentButton {
  final int type;
  final int style;
  final String? label;
  final String? url;
  final bool disabled;

  const DiscordComponentButton({
    required this.type,
    this.style = 2,
    this.label,
    this.url,
    this.disabled = false,
  });

  factory DiscordComponentButton.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as int? ?? 2;
    String? label = json['label'] as String?;
    if (label == null && type == 3) {
      label = json['placeholder'] as String? ?? 'Select Menu';
    }
    return DiscordComponentButton(
      type: type,
      style: json['style'] as int? ?? 2,
      label: label,
      url: json['url'] as String?,
      disabled: json['disabled'] as bool? ?? false,
    );
  }
}

class DiscordMessage {
  final String id;
  final String channelId;
  final String? guildId;
  final DiscordUser author;
  final String content;
  final DateTime timestamp;
  final DateTime? editedTimestamp;
  final bool pinned;
  final int type;
  final List<DiscordAttachment> attachments;
  final List<DiscordEmbed> embeds;
  final List<DiscordReaction> reactions;
  final DiscordMessage? referencedMessage;
  final String? referencedMessageId;
  final List<DiscordComponentButton> components;
  final List<String> stickerNames;

  const DiscordMessage({
    required this.id,
    required this.channelId,
    this.guildId,
    required this.author,
    required this.content,
    required this.timestamp,
    this.editedTimestamp,
    this.pinned = false,
    this.type = 0,
    this.attachments = const [],
    this.embeds = const [],
    this.reactions = const [],
    this.referencedMessage,
    this.referencedMessageId,
    this.components = const [],
    this.stickerNames = const [],
  });

  DiscordMessage copyWith({
    String? content,
    DateTime? editedTimestamp,
    bool? pinned,
    List<DiscordAttachment>? attachments,
    List<DiscordEmbed>? embeds,
    List<DiscordReaction>? reactions,
  }) {
    return DiscordMessage(
      id: id,
      channelId: channelId,
      guildId: guildId,
      author: author,
      content: content ?? this.content,
      timestamp: timestamp,
      editedTimestamp: editedTimestamp ?? this.editedTimestamp,
      pinned: pinned ?? this.pinned,
      type: type,
      attachments: attachments ?? this.attachments,
      embeds: embeds ?? this.embeds,
      reactions: reactions ?? this.reactions,
      referencedMessage: referencedMessage,
      referencedMessageId: referencedMessageId,
      components: components,
      stickerNames: stickerNames,
    );
  }

  factory DiscordMessage.fromJson(Map<String, dynamic> json) {
    final attRaw = json['attachments'] as List<dynamic>? ?? const [];
    final embRaw = json['embeds'] as List<dynamic>? ?? const [];
    final rxnRaw = json['reactions'] as List<dynamic>? ?? const [];
    final compRows = json['components'] as List<dynamic>? ?? const [];
    final stickersRaw = json['sticker_items'] as List<dynamic>? ?? const [];

    final buttons = <DiscordComponentButton>[];
    for (final row in compRows) {
      if (row is Map<String, dynamic>) {
        final children = row['components'] as List<dynamic>?;
        if (children != null) {
          for (final c in children) {
            if (c is Map<String, dynamic>) {
              buttons.add(DiscordComponentButton.fromJson(c));
            }
          }
        } else {
          // V2 Component fallback
          if (row['content'] is String) {
            buttons.add(DiscordComponentButton(
              type: row['type'] as int? ?? 10,
              label: row['content'] as String?,
            ));
          }
        }
      }
    }

    final refJson = json['referenced_message'] as Map<String, dynamic>?;
    final msgRef = json['message_reference'] as Map<String, dynamic>?;

    // Poll summary if present
    String pollText = '';
    if (json['poll'] is Map<String, dynamic>) {
      final poll = json['poll'] as Map<String, dynamic>;
      final q = (poll['question'] as Map<String, dynamic>?)?['text'] ?? 'Poll';
      final answers = (poll['answers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((a) =>
              '• ${(a['poll_media'] as Map<String, dynamic>?)?['text'] ?? ''}')
          .join('\n');
      pollText = '📊 **$q**\n$answers';
    }

    final rawContent = json['content'] as String? ?? '';
    final finalContent = pollText.isEmpty
        ? rawContent
        : (rawContent.isEmpty ? pollText : '$rawContent\n\n$pollText');

    return DiscordMessage(
      id: json['id']?.toString() ?? '0',
      channelId: json['channel_id']?.toString() ?? '0',
      guildId: json['guild_id']?.toString(),
      author: DiscordUser.fromJson(
          json['author'] as Map<String, dynamic>? ?? const {}),
      content: finalContent,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '')
              ?.toLocal() ??
          DateTime.now(),
      editedTimestamp: json['edited_timestamp'] != null
          ? DateTime.tryParse(json['edited_timestamp'] as String)?.toLocal()
          : null,
      pinned: json['pinned'] as bool? ?? false,
      type: json['type'] as int? ?? 0,
      attachments: attRaw
          .whereType<Map<String, dynamic>>()
          .map(DiscordAttachment.fromJson)
          .toList(),
      embeds: embRaw
          .whereType<Map<String, dynamic>>()
          .map(DiscordEmbed.fromJson)
          .toList(),
      reactions: rxnRaw
          .whereType<Map<String, dynamic>>()
          .map(DiscordReaction.fromJson)
          .toList(),
      referencedMessage:
          refJson != null ? DiscordMessage.fromJson(refJson) : null,
      referencedMessageId: msgRef?['message_id']?.toString(),
      components: buttons,
      stickerNames: stickersRaw
          .whereType<Map<String, dynamic>>()
          .map((s) => s['name']?.toString() ?? 'Sticker')
          .toList(),
    );
  }
}

class AuditLogEntry {
  final String id;
  final int actionType;
  final String? userId;
  final String? targetId;
  final String? reason;

  const AuditLogEntry({
    required this.id,
    required this.actionType,
    this.userId,
    this.targetId,
    this.reason,
  });

  String get actionLabel {
    switch (actionType) {
      case 1:
        return '更新伺服器設定';
      case 10:
        return '建立頻道';
      case 11:
        return '更新頻道';
      case 12:
        return '刪除頻道';
      case 20:
        return '踢出成員';
      case 22:
        return '封鎖成員';
      case 23:
        return '解除封鎖';
      case 24:
        return '更新成員';
      case 25:
        return '更新成員身分組';
      case 30:
        return '建立身分組';
      case 31:
        return '更新身分組';
      case 32:
        return '刪除身分組';
      case 40:
        return '建立邀請連結';
      case 50:
        return '建立 Webhook';
      case 72:
        return '刪除訊息';
      case 74:
        return '釘選訊息';
      case 75:
        return '取消釘選訊息';
      default:
        return '操作 #$actionType';
    }
  }

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      id: json['id']?.toString() ?? '0',
      actionType: json['action_type'] as int? ?? 0,
      userId: json['user_id']?.toString(),
      targetId: json['target_id']?.toString(),
      reason: json['reason'] as String?,
    );
  }
}

DateTime snowflakeCreatedAt(String snowflake) {
  final id = BigInt.tryParse(snowflake) ?? BigInt.zero;
  if (id <= BigInt.zero) return DateTime.fromMillisecondsSinceEpoch(1420070400000);
  final ms = (id >> 22).toInt() + 1420070400000;
  return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
}

String encodeJsonSafe(Object value) => jsonEncode(value);
