import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

import '../models/discord_models.dart';

class DiscordApiException implements Exception {
  final int statusCode;
  final String message;

  const DiscordApiException(this.statusCode, this.message);

  @override
  String toString() => 'Discord API Error ($statusCode): $message';
}

class DiscordRestClient {
  static const String _baseUrl = 'https://discord.com/api/v10';
  static const String _userAgent =
      'DiscordBot (https://github.com/aiko-chan-ai/DiscordBotClient, 1.0.0)';

  final String token;
  final http.Client _httpClient;

  DiscordRestClient({required this.token, http.Client? client})
      : _httpClient = client ?? http.Client();

  Map<String, String> _headers({bool jsonContent = true, String? auditReason}) {
    final map = <String, String>{
      'Authorization': 'Bot $token',
      'User-Agent': _userAgent,
      'Accept': 'application/json',
    };
    if (jsonContent) {
      map['Content-Type'] = 'application/json';
    }
    if (auditReason != null && auditReason.isNotEmpty) {
      map['X-Audit-Log-Reason'] = Uri.encodeComponent(auditReason);
    }
    return map;
  }

  Future<dynamic> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? auditReason,
    int retries = 2,
  }) async {
    final uri = Uri.parse('$_baseUrl$path').replace(
      queryParameters: (query != null && query.isNotEmpty) ? query : null,
    );

    final req = http.Request(method, uri);
    req.headers.addAll(_headers(
      jsonContent: body != null,
      auditReason: auditReason,
    ));
    if (body != null) {
      req.body = jsonEncode(body);
    }

    final streamed =
        await _httpClient.send(req).timeout(const Duration(seconds: 20));
    final response = await http.Response.fromStream(streamed);

    if (response.statusCode == 429 && retries > 0) {
      double retryAfterSec = 1.2;
      try {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        retryAfterSec = (data['retry_after'] as num?)?.toDouble() ?? 1.2;
      } catch (_) {}
      final waitMs = ((retryAfterSec * 1000).ceil()).clamp(300, 10000);
      await Future<void>.delayed(Duration(milliseconds: waitMs));
      return _request(
        method,
        path,
        body: body,
        query: query,
        auditReason: auditReason,
        retries: retries - 1,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty || response.statusCode == 204) return null;
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    String errMsg = 'HTTP ${response.statusCode}';
    try {
      final errJson =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      errMsg = errJson['message']?.toString() ?? errMsg;
    } catch (_) {}
    throw DiscordApiException(response.statusCode, errMsg);
  }

  /// Validates the bot token and fetches bot profile + application info.
  Future<BotAccount> validateBotToken() async {
    final meRaw = await _request('GET', '/users/@me') as Map<String, dynamic>;
    if (meRaw['bot'] != true) {
      throw const DiscordApiException(
        400,
        'This token is not a bot token',
      );
    }
    String? appId;
    String? appDescription;
    int appFlags = 0;
    int approxGuilds = 0;
    try {
      // Exact endpoint used by DiscordBotClient/src/AppCore/IPCManager.ts:
      final appRaw = await _request(
        'GET',
        '/applications/@me',
        query: {'with_counts': 'true'},
      ) as Map<String, dynamic>;
      appId = appRaw['id']?.toString();
      appDescription = appRaw['description'] as String?;
      appFlags = appRaw['flags'] as int? ?? 0;
      approxGuilds = (appRaw['bot_approximate_guild_count'] as int?) ??
          (appRaw['approximate_guild_count'] as int?) ??
          0;
    } catch (_) {
      appId = meRaw['id']?.toString();
    }

    return BotAccount(
      token: token,
      id: meRaw['id']?.toString() ?? '',
      username: meRaw['username'] as String? ?? 'Bot',
      discriminator: meRaw['discriminator']?.toString() ?? '0',
      globalName: meRaw['global_name'] as String?,
      avatar: meRaw['avatar'] as String?,
      banner: meRaw['banner'] as String?,
      accentColor: meRaw['accent_color'] as int?,
      bio: (appDescription != null && appDescription.trim().isNotEmpty)
          ? appDescription.trim()
          : (meRaw['bio'] as String?),
      applicationId: appId ?? meRaw['id']?.toString(),
      publicFlags: meRaw['public_flags'] as int? ?? (meRaw['flags'] as int? ?? 0),
      applicationFlags: appFlags,
      approximateGuildCount: approxGuilds,
    );
  }

  Future<List<DiscordGuild>> getUserGuilds() async {
    final list = await _request(
      'GET',
      '/users/@me/guilds',
      query: {'with_counts': 'true'},
    ) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map((g) => DiscordGuild.fromJson(g))
        .toList();
  }

  Future<DiscordGuild> getGuildDetails(
    String guildId, {
    required String botUserId,
  }) async {
    final guildFuture = _request(
      'GET',
      '/guilds/$guildId',
      query: {'with_counts': 'true'},
    );
    final channelsFuture = _request('GET', '/guilds/$guildId/channels');
    final meMemberFuture = _request(
      'GET',
      '/guilds/$guildId/members/$botUserId',
    ).catchError((_) => null);

    final results =
        await Future.wait([guildFuture, channelsFuture, meMemberFuture]);
    final guildJson = results[0] as Map<String, dynamic>;
    final channelsJson = results[1] as List<dynamic>;
    final meMemberJson = results[2] as Map<String, dynamic>?;

    guildJson['channels'] = channelsJson;
    final baseGuild =
        DiscordGuild.fromJson(guildJson, currentBotUserId: botUserId);

    if (meMemberJson != null && meMemberJson['roles'] is List<dynamic>) {
      final botRoles = (meMemberJson['roles'] as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      return baseGuild.copyWith(botRoleIds: botRoles, channelsLoaded: true);
    }
    return baseGuild.copyWith(channelsLoaded: true);
  }

  Future<List<DiscordChannel>> getGuildChannels(String guildId) async {
    final list =
        await _request('GET', '/guilds/$guildId/channels') as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map((c) => DiscordChannel.fromJson(c, guildId: guildId))
        .toList();
  }

  Future<List<DiscordMessage>> getChannelMessages(
    String channelId, {
    String? before,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (before != null && before.isNotEmpty) {
      query['before'] = before;
    }
    final list = await _request(
      'GET',
      '/channels/$channelId/messages',
      query: query,
    ) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(DiscordMessage.fromJson)
        .toList();
  }

  Future<List<DiscordMessage>> getPinnedMessages(String channelId) async {
    final list =
        await _request('GET', '/channels/$channelId/pins') as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(DiscordMessage.fromJson)
        .toList();
  }

  Future<DiscordMessage> sendMessage(
    String channelId, {
    String content = '',
    String? replyToMessageId,
    List<DiscordEmbed>? embeds,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final payload = <String, dynamic>{};
    if (content.isNotEmpty) {
      payload['content'] = content;
    }
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      payload['message_reference'] = {
        'message_id': replyToMessageId,
        'fail_if_not_exists': false,
      };
    }
    if (embeds != null && embeds.isNotEmpty) {
      payload['embeds'] = embeds.map((e) => e.toJson()).toList();
    }

    if (fileBytes != null && fileName != null) {
      final uri = Uri.parse('$_baseUrl/channels/$channelId/messages');
      final multipart = http.MultipartRequest('POST', uri);
      multipart.headers.addAll(_headers(jsonContent: false));
      multipart.fields['payload_json'] = jsonEncode(payload);
      multipart.files.add(http.MultipartFile.fromBytes(
        'files[0]',
        fileBytes,
        filename: fileName,
      ));

      final streamed =
          await _httpClient.send(multipart).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return DiscordMessage.fromJson(json);
      }
      String errMsg = 'HTTP ${response.statusCode}';
      try {
        final errJson =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        errMsg = errJson['message']?.toString() ?? errMsg;
      } catch (_) {}
      throw DiscordApiException(response.statusCode, errMsg);
    }

    final res = await _request(
      'POST',
      '/channels/$channelId/messages',
      body: payload,
    ) as Map<String, dynamic>;
    return DiscordMessage.fromJson(res);
  }

  Future<DiscordMessage> editMessage(
    String channelId,
    String messageId, {
    String? content,
    List<DiscordEmbed>? embeds,
  }) async {
    final body = <String, dynamic>{};
    if (content != null) body['content'] = content;
    if (embeds != null) {
      body['embeds'] = embeds.map((e) => e.toJson()).toList();
    }
    final res = await _request(
      'PATCH',
      '/channels/$channelId/messages/$messageId',
      body: body,
    ) as Map<String, dynamic>;
    return DiscordMessage.fromJson(res);
  }

  /// Bulk deletes 2..100 messages younger than 14 days (used by /purge command).
  Future<void> bulkDeleteMessages(
    String channelId,
    List<String> messageIds,
  ) async {
    await _request(
      'POST',
      '/channels/$channelId/messages/bulk-delete',
      body: {'messages': messageIds},
    );
  }

  /// Fetches archived public threads in a channel or forum.
  Future<List<DiscordChannel>> getArchivedPublicThreads(
    String channelId, {
    String? guildId,
  }) async {
    final res = await _request(
      'GET',
      '/channels/$channelId/threads/archived/public',
    ) as Map<String, dynamic>;
    final threads = res['threads'] as List<dynamic>? ?? const [];
    return threads
        .whereType<Map<String, dynamic>>()
        .map((t) => DiscordChannel.fromJson(t, guildId: guildId))
        .toList();
  }

  Future<void> deleteMessage(String channelId, String messageId) async {
    await _request('DELETE', '/channels/$channelId/messages/$messageId');
  }

  Future<void> pinMessage(String channelId, String messageId) async {
    await _request('PUT', '/channels/$channelId/pins/$messageId');
  }

  Future<void> unpinMessage(String channelId, String messageId) async {
    await _request('DELETE', '/channels/$channelId/pins/$messageId');
  }

  Future<void> addReaction(
    String channelId,
    String messageId,
    String emojiApiIdentifier,
  ) async {
    final encoded = Uri.encodeComponent(emojiApiIdentifier);
    await _request(
      'PUT',
      '/channels/$channelId/messages/$messageId/reactions/$encoded/@me',
    );
  }

  Future<void> removeOwnReaction(
    String channelId,
    String messageId,
    String emojiApiIdentifier,
  ) async {
    final encoded = Uri.encodeComponent(emojiApiIdentifier);
    await _request(
      'DELETE',
      '/channels/$channelId/messages/$messageId/reactions/$encoded/@me',
    );
  }

  Future<void> triggerTyping(String channelId) async {
    await _request('POST', '/channels/$channelId/typing');
  }

  /// Opens or retrieves a Direct Message channel with a target user ID.
  Future<DiscordChannel> createDirectMessage(String recipientUserId) async {
    final res = await _request(
      'POST',
      '/users/@me/channels',
      body: {'recipient_id': recipientUserId.trim()},
    ) as Map<String, dynamic>;
    return DiscordChannel.fromJson(res);
  }

  /// Fetches full DiscordUser object (`banner`, `accent_color`, `public_flags`, `avatar`).
  Future<DiscordUser> getUser(String userId) async {
    final res =
        await _request('GET', '/users/${userId.trim()}') as Map<String, dynamic>;
    return DiscordUser.fromJson(res, profileFetched: true);
  }

  /// Fetches a specific guild member (`nick`, `roles`, `joined_at`, `avatar`).
  Future<DiscordMember> getGuildMember(String guildId, String userId) async {
    final res = await _request(
      'GET',
      '/guilds/${guildId.trim()}/members/${userId.trim()}',
    ) as Map<String, dynamic>;
    return DiscordMember.fromJson(res);
  }

  /// Fetches Discord's built-in default Soundboard sounds.
  Future<List<SoundboardSound>> getDefaultSoundboardSounds() async {
    final res = await _request('GET', '/soundboard-default-sounds');
    final list = res is List<dynamic>
        ? res
        : (res is Map<String, dynamic>
            ? (res['items'] as List<dynamic>? ?? const [])
            : const <dynamic>[]);
    return list
        .whereType<Map<String, dynamic>>()
        .map((s) => SoundboardSound.fromJson(s))
        .where((s) => s.available && s.soundId != '0')
        .toList();
  }

  /// Fetches custom Soundboard sounds uploaded to [guildId].
  Future<List<SoundboardSound>> getGuildSoundboardSounds(String guildId) async {
    final res = await _request('GET', '/guilds/${guildId.trim()}/soundboard-sounds');
    final list = res is Map<String, dynamic>
        ? (res['items'] as List<dynamic>? ?? const [])
        : (res is List<dynamic> ? res : const <dynamic>[]);
    return list
        .whereType<Map<String, dynamic>>()
        .map((s) => SoundboardSound.fromJson(s, fallbackGuildId: guildId))
        .where((s) => s.available && s.soundId != '0')
        .toList();
  }

  /// Triggers a Soundboard sound clip in [channelId] (bot must be connected & unmuted).
  Future<void> sendSoundboardSound(
    String channelId, {
    required String soundId,
    String? sourceGuildId,
  }) async {
    await _request(
      'POST',
      '/channels/${channelId.trim()}/send-soundboard-sound',
      body: {
        'sound_id': soundId,
        if (sourceGuildId != null && sourceGuildId.isNotEmpty)
          'source_guild_id': sourceGuildId,
      },
    );
  }

  Future<List<DiscordMember>> getGuildMembers(
    String guildId, {
    int limit = 100,
  }) async {
    final list = await _request(
      'GET',
      '/guilds/$guildId/members',
      query: {'limit': '$limit'},
    ) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(DiscordMember.fromJson)
        .toList();
  }

  Future<List<DiscordMember>> searchGuildMembers(
    String guildId,
    String query,
  ) async {
    final list = await _request(
      'GET',
      '/guilds/$guildId/members/search',
      query: {'query': query, 'limit': '50'},
    ) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map(DiscordMember.fromJson)
        .toList();
  }

  Future<void> kickMember(
    String guildId,
    String userId, {
    String? reason,
  }) async {
    await _request(
      'DELETE',
      '/guilds/$guildId/members/$userId',
      auditReason: reason,
    );
  }

  Future<void> banMember(
    String guildId,
    String userId, {
    String? reason,
  }) async {
    await _request(
      'PUT',
      '/guilds/$guildId/bans/$userId',
      body: {'delete_message_seconds': 0},
      auditReason: reason,
    );
  }

  Future<DiscordChannel> createGuildChannel(
    String guildId, {
    required String name,
    int type = 0,
    String? topic,
    String? parentId,
  }) async {
    final res = await _request(
      'POST',
      '/guilds/$guildId/channels',
      body: {
        'name': name,
        'type': type,
        if (topic != null && topic.isNotEmpty) 'topic': topic,
        if (parentId != null && parentId.isNotEmpty) 'parent_id': parentId,
      },
    ) as Map<String, dynamic>;
    return DiscordChannel.fromJson(res, guildId: guildId);
  }

  Future<DiscordChannel> modifyChannel(
    String channelId, {
    String? name,
    String? topic,
    int? rateLimitPerUser,
  }) async {
    final res = await _request(
      'PATCH',
      '/channels/$channelId',
      body: {
        if (name != null) 'name': name,
        if (topic != null) 'topic': topic,
        if (rateLimitPerUser != null) 'rate_limit_per_user': rateLimitPerUser,
      },
    ) as Map<String, dynamic>;
    return DiscordChannel.fromJson(res);
  }

  Future<void> deleteChannel(String channelId) async {
    await _request('DELETE', '/channels/$channelId');
  }

  Future<String> createChannelInvite(
    String channelId, {
    int maxAge = 86400,
    int maxUses = 0,
  }) async {
    final res = await _request(
      'POST',
      '/channels/$channelId/invites',
      body: {'max_age': maxAge, 'max_uses': maxUses},
    ) as Map<String, dynamic>;
    final code = res['code']?.toString() ?? '';
    return 'https://discord.gg/$code';
  }

  Future<List<AuditLogEntry>> getGuildAuditLogs(String guildId) async {
    final res = await _request(
      'GET',
      '/guilds/$guildId/audit-logs',
      query: {'limit': '30'},
    ) as Map<String, dynamic>;
    final entries = res['audit_log_entries'] as List<dynamic>? ?? const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map(AuditLogEntry.fromJson)
        .toList();
  }

  Future<DiscordGuild> createGuild(String name) async {
    final res = await _request(
      'POST',
      '/guilds',
      body: {'name': name.trim()},
    ) as Map<String, dynamic>;
    return DiscordGuild.fromJson(res);
  }

  Future<void> leaveGuild(String guildId) async {
    await _request('DELETE', '/users/@me/guilds/$guildId');
  }

  void dispose() {
    _httpClient.close();
  }
}
