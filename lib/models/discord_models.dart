import 'dart:convert';

class EcoSettings {
  final bool oledBlackMode;
  final bool ecoPowerSaving;
  final int backgroundSuspendSeconds;
  final bool enableMessageContentIntent;
  final bool enableMembersIntent;
  final bool enablePresenceIntent;
  final bool silentTyping;

  const EcoSettings({
    this.oledBlackMode = true,
    this.ecoPowerSaving = true,
    this.backgroundSuspendSeconds = 25,
    this.enableMessageContentIntent = true,
    this.enableMembersIntent = true,
    this.enablePresenceIntent = false,
    this.silentTyping = true,
  });

  /// Computes the Discord Gateway v10 Intents bitmask, automatically filtering
  /// privileged intents against the bot's actual ApplicationFlags from
  /// `/applications/@me` (matching DiscordBotClient/src/AppCore/IPCManager.ts).
  int computeIntentsBitmask({
    int? applicationFlags,
    bool stripPrivileged = false,
  }) {
    int mask = 0;
    mask |= (1 << 0); // GUILDS
    mask |= (1 << 7); // GUILD_VOICE_STATES (standard non-privileged intent for live voice channels!)
    mask |= (1 << 9); // GUILD_MESSAGES
    mask |= (1 << 10); // GUILD_MESSAGE_REACTIONS
    mask |= (1 << 12); // DIRECT_MESSAGES
    mask |= (1 << 13); // DIRECT_MESSAGE_REACTIONS

    if (!ecoPowerSaving) {
      mask |= (1 << 11); // GUILD_MESSAGE_TYPING
      mask |= (1 << 14); // DIRECT_MESSAGE_TYPING
    }

    if (!stripPrivileged) {
      final hasAppFlags = applicationFlags != null && applicationFlags > 0;

      // ApplicationFlags: GATEWAY_GUILD_MEMBERS (1<<14) | LIMITED (1<<15)
      final appAllowsMembers = !hasAppFlags ||
          ((applicationFlags & ((1 << 14) | (1 << 15))) != 0);
      if (enableMembersIntent && appAllowsMembers) {
        mask |= (1 << 1); // GUILD_MEMBERS
      }

      // ApplicationFlags: GATEWAY_PRESENCE (1<<12) | LIMITED (1<<13)
      final appAllowsPresence = !hasAppFlags ||
          ((applicationFlags & ((1 << 12) | (1 << 13))) != 0);
      if (enablePresenceIntent && !ecoPowerSaving && appAllowsPresence) {
        mask |= (1 << 8); // GUILD_PRESENCES
      }

      // ApplicationFlags: GATEWAY_MESSAGE_CONTENT (1<<18) | LIMITED (1<<19)
      final appAllowsContent = !hasAppFlags ||
          ((applicationFlags & ((1 << 18) | (1 << 19))) != 0);
      if (enableMessageContentIntent && appAllowsContent) {
        mask |= (1 << 15); // MESSAGE_CONTENT
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
      };

  factory EcoSettings.fromJson(Map<String, dynamic> json) {
    return EcoSettings(
      oledBlackMode: json['oledBlackMode'] as bool? ?? true,
      ecoPowerSaving: json['ecoPowerSaving'] as bool? ?? true,
      backgroundSuspendSeconds: json['backgroundSuspendSeconds'] as int? ?? 25,
      enableMessageContentIntent:
          json['enableMessageContentIntent'] as bool? ?? true,
      enableMembersIntent: json['enableMembersIntent'] as bool? ?? true,
      enablePresenceIntent: json['enablePresenceIntent'] as bool? ?? false,
      silentTyping: json['silentTyping'] as bool? ?? true,
    );
  }
}

class DiscordBadgeInfo {
  final String id;
  final String description;
  final String iconHash;

  const DiscordBadgeInfo({
    required this.id,
    required this.description,
    required this.iconHash,
  });

  String get iconUrl => 'https://cdn.discordapp.com/badge-icons/$iconHash.png';
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
  final int publicFlags;
  final int applicationFlags;
  final int approximateGuildCount;

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
    this.publicFlags = 0,
    this.applicationFlags = 0,
    this.approximateGuildCount = 0,
  });

  String get displayName =>
      (globalName != null && globalName!.isNotEmpty) ? globalName! : username;

  String get tag => (discriminator == '0' || discriminator == '0000' || discriminator.isEmpty)
      ? username
      : '$username#$discriminator';

  /// UserFlags.VerifiedBot = 1 << 16 (65536)
  bool get isVerifiedBot => (publicFlags & (1 << 16)) != 0;

  bool get hasMessageContentIntent =>
      applicationFlags == 0 ||
      (applicationFlags & ((1 << 18) | (1 << 19))) != 0;

  /// Computes ONLY genuine Discord badges earned by this account/application
  /// (matching DiscordBotClient/src/AppUtils/UserBadges.ts).
  List<DiscordBadgeInfo> get realBadges {
    final list = <DiscordBadgeInfo>[];
    if ((publicFlags & (1 << 0)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'staff',
        description: 'Discord Staff',
        iconHash: '5e74e9b61934fc1f67c65515d1f7e60d',
      ));
    }
    if ((publicFlags & (1 << 1)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'partner',
        description: 'Partnered Server Owner',
        iconHash: '3f9748e53446a137a052f3454e2de41e',
      ));
    }
    if ((publicFlags & (1 << 6)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'hypesquad_house_1',
        description: 'HypeSquad Bravery',
        iconHash: '8a88d63823d8a71cd5e390baa45efa02',
      ));
    }
    if ((publicFlags & (1 << 7)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'hypesquad_house_2',
        description: 'HypeSquad Brilliance',
        iconHash: '011940fd013da3f7fb926e4a1cd2e618',
      ));
    }
    if ((publicFlags & (1 << 8)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'hypesquad_house_3',
        description: 'HypeSquad Balance',
        iconHash: '3aa41de486fa12454c3761e8e223442e',
      ));
    }
    if ((publicFlags & (1 << 17)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'verified_developer',
        description: 'Early Verified Bot Developer',
        iconHash: '6df5892e0f35b051f8b61eace34f4967',
      ));
    }
    if ((publicFlags & (1 << 22)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'active_developer',
        description: 'Active Developer',
        iconHash: '6bdc42827a38498929a4920da12695d9',
      ));
    }
    // ApplicationFlags.ApplicationAutoModerationRuleCreateBadge = 1 << 6
    if ((applicationFlags & (1 << 6)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'automod',
        description: 'Uses AutoMod',
        iconHash: 'f2459b691ac7453ed6039bbcfaccbfcd',
      ));
    }
    // ApplicationFlags.ApplicationCommandBadge = 1 << 23
    if ((applicationFlags & (1 << 23)) != 0) {
      list.add(const DiscordBadgeInfo(
        id: 'bot_commands',
        description: 'Supports Commands',
        iconHash: '6f9e37f9029ff57aef81db857890005e',
      ));
    }
    return list;
  }

  String avatarUrl({int size = 64}) {
    if (avatar == null || avatar!.isEmpty) {
      final idx = ((BigInt.tryParse(id) ?? BigInt.zero) >> 22).toInt().abs() % 6;
      return 'https://cdn.discordapp.com/embed/avatars/$idx.png';
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
        'publicFlags': publicFlags,
        'applicationFlags': applicationFlags,
        'approximateGuildCount': approximateGuildCount,
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
      publicFlags: json['publicFlags'] as int? ?? 0,
      applicationFlags: json['applicationFlags'] as int? ?? 0,
      approximateGuildCount: json['approximateGuildCount'] as int? ?? 0,
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
  final int publicFlags;

  const DiscordUser({
    required this.id,
    required this.username,
    this.discriminator = '0',
    this.globalName,
    this.avatar,
    this.bot = false,
    this.publicFlags = 0,
  });

  String get displayName =>
      (globalName != null && globalName!.isNotEmpty) ? globalName! : username;

  bool get isVerifiedBot => bot && (publicFlags & (1 << 16)) != 0;

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
        'public_flags': publicFlags,
      };

  factory DiscordUser.fromJson(Map<String, dynamic> json) {
    return DiscordUser(
      id: json['id']?.toString() ?? '0',
      username: json['username'] as String? ?? 'Unknown',
      discriminator: json['discriminator']?.toString() ?? '0',
      globalName: json['global_name'] as String?,
      avatar: json['avatar'] as String?,
      bot: json['bot'] as bool? ?? false,
      publicFlags: json['public_flags'] as int? ?? 0,
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

  int? resolveColor(Map<String, DiscordRole> guildRoles) {
    DiscordRole? highestColored;
    for (final rId in roleIds) {
      final r = guildRoles[rId];
      if (r != null && r.color != 0) {
        if (highestColored == null || r.position > highestColored.position) {
          highestColored = r;
        }
      }
    }
    return highestColored?.color;
  }

  String? resolveHoistRoleId(Map<String, DiscordRole> guildRoles) {
    DiscordRole? highestHoist;
    for (final rId in roleIds) {
      final r = guildRoles[rId];
      if (r != null && r.hoist) {
        if (highestHoist == null || r.position > highestHoist.position) {
          highestHoist = r;
        }
      }
    }
    return highestHoist?.id;
  }

  factory DiscordMember.fromJson(
    Map<String, dynamic> json, {
    DiscordUser? fallbackUser,
  }) {
    final userMap = json['user'] as Map<String, dynamic>?;
    final rolesRaw = json['roles'] as List<dynamic>? ?? const [];
    return DiscordMember(
      user: userMap != null
          ? DiscordUser.fromJson(userMap)
          : (fallbackUser ?? const DiscordUser(id: '0', username: 'Unknown')),
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
    for (final ow in channel.permissionOverwrites) {
      if (ow.id == guild.id) {
        perms &= ~ow.deny;
        perms |= ow.allow;
      }
    }
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
  final int? messageCount;
  final int userLimit;
  final int? bitrate;

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
    this.messageCount,
    this.userLimit = 0,
    this.bitrate,
  });

  bool get isCategory => type == 4;
  bool get isDm => type == 1 || type == 3;
  bool get isVoice => type == 2 || type == 13;
  bool get isStageVoice => type == 13;
  bool get isForum => type == 15 || type == 16;
  bool get isThread => type == 10 || type == 11 || type == 12;

  /// Official Discord sort bucket:
  /// Bucket 0: Text (0), Announcement (5), Forum (15), Media (16), Directory (14)
  /// Bucket 1: Voice (2), Stage Voice (13) — ALWAYS sorted after Bucket 0 within each category!
  int get sortBucket => (type == 2 || type == 13) ? 1 : 0;

  static int compareCategories(DiscordChannel a, DiscordChannel b) {
    final posCmp = a.position.compareTo(b.position);
    if (posCmp != 0) return posCmp;
    return compareSnowflakes(a.id, b.id);
  }

  static int compareGuildChannels(DiscordChannel a, DiscordChannel b) {
    final bucketCmp = a.sortBucket.compareTo(b.sortBucket);
    if (bucketCmp != 0) return bucketCmp;
    final posCmp = a.position.compareTo(b.position);
    if (posCmp != 0) return posCmp;
    return compareSnowflakes(a.id, b.id);
  }

  /// Visible in the server's main channel tree (threads live under parent/forum).
  bool get isTopLevelChannel =>
      type == 0 || type == 2 || type == 5 || type == 13 || type == 15 || type == 16;

  bool get isMessageable =>
      type == 0 ||
      type == 1 ||
      type == 2 ||
      type == 3 ||
      type == 5 ||
      type == 10 ||
      type == 11 ||
      type == 12 ||
      type == 13 ||
      type == 15;

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
    int? userLimit,
    int? bitrate,
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
      messageCount: messageCount,
      userLimit: userLimit ?? this.userLimit,
      bitrate: bitrate ?? this.bitrate,
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
        'user_limit': userLimit,
        if (bitrate != null) 'bitrate': bitrate,
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
      messageCount: json['message_count'] as int?,
      userLimit: json['user_limit'] as int? ?? 0,
      bitrate: json['bitrate'] as int?,
    );
  }
}

class VoiceState {
  final String? guildId;
  final String? channelId;
  final String userId;
  final String sessionId;
  final bool deaf;
  final bool mute;
  final bool selfDeaf;
  final bool selfMute;
  final bool selfStream;
  final bool selfVideo;
  final bool suppress;
  final DiscordMember? member;

  const VoiceState({
    this.guildId,
    this.channelId,
    required this.userId,
    required this.sessionId,
    this.deaf = false,
    this.mute = false,
    this.selfDeaf = false,
    this.selfMute = false,
    this.selfStream = false,
    this.selfVideo = false,
    this.suppress = false,
    this.member,
  });

  bool get isMuted => mute || selfMute || suppress;
  bool get isDeafened => deaf || selfDeaf;

  factory VoiceState.fromJson(Map<String, dynamic> json, {String? guildId}) {
    final mJson = json['member'] as Map<String, dynamic>?;
    return VoiceState(
      guildId: json['guild_id']?.toString() ?? guildId,
      channelId: json['channel_id']?.toString(),
      userId: json['user_id']?.toString() ?? '0',
      sessionId: json['session_id']?.toString() ?? '',
      deaf: json['deaf'] as bool? ?? false,
      mute: json['mute'] as bool? ?? false,
      selfDeaf: json['self_deaf'] as bool? ?? false,
      selfMute: json['self_mute'] as bool? ?? false,
      selfStream: json['self_stream'] as bool? ?? false,
      selfVideo: json['self_video'] as bool? ?? false,
      suppress: json['suppress'] as bool? ?? false,
      member: mJson != null ? DiscordMember.fromJson(mJson) : null,
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
  final String? banner;
  final String? ownerId;
  final int? memberCount;
  final List<String> features;
  final String? rulesChannelId;
  final Map<String, DiscordRole> roles;
  final List<DiscordChannel> channels;
  final List<DiscordEmoji> emojis;
  final Map<String, DiscordMember> cachedMembers;
  final Map<String, VoiceState> voiceStates;
  final List<String> botRoleIds;
  final bool channelsLoaded;

  const DiscordGuild({
    required this.id,
    required this.name,
    this.icon,
    this.banner,
    this.ownerId,
    this.memberCount,
    this.features = const [],
    this.rulesChannelId,
    this.roles = const {},
    this.channels = const [],
    this.emojis = const [],
    this.cachedMembers = const {},
    this.voiceStates = const {},
    this.botRoleIds = const [],
    this.channelsLoaded = false,
  });

  List<VoiceState> voiceStatesForChannel(String channelId) {
    return voiceStates.values
        .where((vs) => vs.channelId == channelId)
        .toList(growable: false);
  }

  bool get isCommunity => features.contains('COMMUNITY');
  bool get isVerified => features.contains('VERIFIED');
  bool get isPartnered => features.contains('PARTNERED');
  bool get hasOnboarding =>
      features.contains('GUILD_ONBOARDING') || isCommunity;

  String? iconUrl({int size = 64}) {
    if (icon == null || icon!.isEmpty) return null;
    return 'https://cdn.discordapp.com/icons/$id/$icon.webp?size=$size';
  }

  String get initials {
    final words = name.trim().split(RegExp(r'\s+'));
    if (words.isEmpty || words.first.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(1, 3));
    }
    return words.take(3).map((w) => w.isNotEmpty ? w[0] : '').join();
  }

  DiscordGuild copyWith({
    String? name,
    String? icon,
    String? banner,
    String? ownerId,
    int? memberCount,
    List<String>? features,
    String? rulesChannelId,
    Map<String, DiscordRole>? roles,
    List<DiscordChannel>? channels,
    List<DiscordEmoji>? emojis,
    Map<String, DiscordMember>? cachedMembers,
    Map<String, VoiceState>? voiceStates,
    List<String>? botRoleIds,
    bool? channelsLoaded,
  }) {
    return DiscordGuild(
      id: id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      banner: banner ?? this.banner,
      ownerId: ownerId ?? this.ownerId,
      memberCount: memberCount ?? this.memberCount,
      features: features ?? this.features,
      rulesChannelId: rulesChannelId ?? this.rulesChannelId,
      roles: roles ?? this.roles,
      channels: channels ?? this.channels,
      emojis: emojis ?? this.emojis,
      cachedMembers: cachedMembers ?? this.cachedMembers,
      voiceStates: voiceStates ?? this.voiceStates,
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

    final featuresRaw = json['features'] as List<dynamic>? ?? const [];
    final parsedFeatures = featuresRaw.map((e) => e.toString()).toList();

    final membersMap = <String, DiscordMember>{};
    List<String> botRoles = const [];
    if (json['members'] is List<dynamic>) {
      for (final m in (json['members'] as List<dynamic>)) {
        if (m is Map<String, dynamic>) {
          final member = DiscordMember.fromJson(m);
          if (member.user.id != '0') {
            membersMap[member.user.id] = member;
          }
          if (currentBotUserId != null && member.user.id == currentBotUserId) {
            botRoles = member.roleIds;
          }
        }
      }
    }

    final voiceStatesMap = <String, VoiceState>{};
    if (json['voice_states'] is List<dynamic>) {
      for (final vsRaw in (json['voice_states'] as List<dynamic>)) {
        if (vsRaw is Map<String, dynamic>) {
          final vs = VoiceState.fromJson(vsRaw, guildId: guildId);
          if (vs.channelId != null && vs.userId != '0') {
            voiceStatesMap[vs.userId] = vs;
            if (vs.member != null && vs.member!.user.id != '0') {
              membersMap[vs.member!.user.id] = vs.member!;
            }
          }
        }
      }
    }

    return DiscordGuild(
      id: guildId,
      name: json['name'] as String? ?? 'Server',
      icon: json['icon'] as String?,
      banner: json['banner'] as String?,
      ownerId: json['owner_id']?.toString(),
      memberCount: json['member_count'] as int? ??
          json['approximate_member_count'] as int?,
      features: parsedFeatures,
      rulesChannelId: json['rules_channel_id']?.toString(),
      roles: rolesMap,
      channels: parsedChannels,
      emojis: parsedEmojis,
      cachedMembers: membersMap,
      voiceStates: voiceStatesMap,
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
  final String? memberNick;
  final List<String> memberRoleIds;
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
    this.memberNick,
    this.memberRoleIds = const [],
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

  String authorDisplayName(DiscordGuild? guild) {
    if (memberNick != null && memberNick!.isNotEmpty) return memberNick!;
    final cached = guild?.cachedMembers[author.id];
    if (cached?.nick != null && cached!.nick!.isNotEmpty) return cached.nick!;
    return author.displayName;
  }

  int? authorRoleColor(DiscordGuild? guild) {
    if (guild == null || guild.roles.isEmpty) return null;
    final roles = memberRoleIds.isNotEmpty
        ? memberRoleIds
        : (guild.cachedMembers[author.id]?.roleIds ?? const []);
    DiscordRole? highest;
    for (final rId in roles) {
      final r = guild.roles[rId];
      if (r != null && r.color != 0) {
        if (highest == null || r.position > highest.position) {
          highest = r;
        }
      }
    }
    return highest?.color;
  }

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
      memberNick: memberNick,
      memberRoleIds: memberRoleIds,
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
    final memberJson = json['member'] as Map<String, dynamic>?;
    final memberRoles = (memberJson?['roles'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();

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
        } else if (row['content'] is String) {
          buttons.add(DiscordComponentButton(
            type: row['type'] as int? ?? 10,
            label: row['content'] as String?,
          ));
        }
      }
    }

    final refJson = json['referenced_message'] as Map<String, dynamic>?;
    final msgRef = json['message_reference'] as Map<String, dynamic>?;

    String pollText = '';
    if (json['poll'] is Map<String, dynamic>) {
      final poll = json['poll'] as Map<String, dynamic>;
      final q = (poll['question'] as Map<String, dynamic>?)?['text'] ?? 'Poll';
      final answers = (poll['answers'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((a) =>
              '• ${(a['poll_media'] as Map<String, dynamic>?)?['text'] ?? ''}')
          .join('\n');
      pollText = '**$q**\n$answers';
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
      memberNick: memberJson?['nick'] as String?,
      memberRoleIds: memberRoles,
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
  if (id <= BigInt.zero) {
    return DateTime.fromMillisecondsSinceEpoch(1420070400000);
  }
  final ms = (id >> 22).toInt() + 1420070400000;
  return DateTime.fromMillisecondsSinceEpoch(ms).toLocal();
}

int compareSnowflakes(String? a, String? b) {
  final ba = BigInt.tryParse(a ?? '0') ?? BigInt.zero;
  final bb = BigInt.tryParse(b ?? '0') ?? BigInt.zero;
  return ba.compareTo(bb);
}

String encodeJsonSafe(Object value) => jsonEncode(value);
