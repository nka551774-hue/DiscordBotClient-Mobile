import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';
import 'settings_sheet.dart';
import 'vencord_sheets.dart';

/// Opens the authentic 2025/2026 Discord Mobile User Profile Modal Sheet
/// for any user or bot (in Guild channels, Direct Messages, Member List, or Voice Rooms).
Future<void> showUserProfileSheet(
  BuildContext context, {
  required BotClientController controller,
  required DiscordUser initialUser,
  DiscordMember? initialMember,
  String? guildId,
  VoidCallback? onNavigateToDm,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DiscordUserProfileModal(
      controller: controller,
      initialUser: initialUser,
      initialMember: initialMember,
      guildId: guildId,
      onNavigateToDm: onNavigateToDm,
    ),
  );
}

/// Resolves a user by Snowflake [userId] (e.g. from an inline `<@uid>` mention)
/// and opens their Discord Mobile User Profile Sheet.
Future<void> showUserProfileById(
  BuildContext context, {
  required BotClientController controller,
  required String userId,
  String? guildId,
  VoidCallback? onNavigateToDm,
}) async {
  final guild = guildId != null ? controller.findGuildById(guildId) : null;
  final cachedMember = guild?.cachedMembers[userId];
  final acc = controller.activeAccount;

  DiscordUser initialUser;
  if (acc != null && acc.id == userId) {
    initialUser = DiscordUser(
      id: acc.id,
      username: acc.username,
      discriminator: acc.discriminator,
      globalName: acc.globalName,
      avatar: acc.avatar,
      banner: acc.banner,
      accentColor: acc.accentColor,
      bot: true,
      publicFlags: acc.publicFlags,
      profileFetched: true,
    );
  } else if (cachedMember != null) {
    initialUser = cachedMember.user;
  } else {
    initialUser = controller.getCachedUser(userId) ??
        DiscordUser(id: userId, username: 'User $userId');
  }

  await showUserProfileSheet(
    context,
    controller: controller,
    initialUser: initialUser,
    initialMember: cachedMember,
    guildId: guildId,
    onNavigateToDm: onNavigateToDm,
  );
}

class _DiscordUserProfileModal extends StatefulWidget {
  final BotClientController controller;
  final DiscordUser initialUser;
  final DiscordMember? initialMember;
  final String? guildId;
  final VoidCallback? onNavigateToDm;

  const _DiscordUserProfileModal({
    required this.controller,
    required this.initialUser,
    this.initialMember,
    this.guildId,
    this.onNavigateToDm,
  });

  @override
  State<_DiscordUserProfileModal> createState() =>
      _DiscordUserProfileModalState();
}

class _DiscordUserProfileModalState extends State<_DiscordUserProfileModal> {
  late DiscordUser _user;
  DiscordMember? _member;
  bool _openingDm = false;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
    _member = widget.initialMember ??
        (widget.guildId != null
            ? widget.controller
                .findGuildById(widget.guildId)
                ?.cachedMembers[widget.initialUser.id]
            : null);
    _loadRichProfile();
  }

  Future<void> _loadRichProfile() async {
    final (richUser, richMember) = await widget.controller.fetchRichUserProfile(
      _user.id,
      guildId: widget.guildId,
    );
    if (!mounted) return;
    if (richUser != null || richMember != null) {
      setState(() {
        if (richUser != null) _user = richUser;
        if (richMember != null) _member = richMember;
      });
    }
  }

  Color _deriveFallbackBannerColor(String id) {
    const palette = [
      Color(0xFF5865F2),
      Color(0xFF3B4252),
      Color(0xFF2B5B84),
      Color(0xFF237A57),
      Color(0xFF5E3B76),
    ];
    final idx = (int.tryParse(
                id.substring(id.length.clamp(0, 4) > 3 ? id.length - 3 : 0)) ??
            0) %
        palette.length;
    return palette[idx];
  }

  String _formatDateZh(DateTime dt) =>
      '${dt.year}年${dt.month}月${dt.day}日';

  void _showMoreActionsMenu(
    BuildContext context, {
    required DiscordPalette p,
    required DiscordGuild? guild,
    required bool canKick,
    required bool canBan,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (menuCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: p.sidebarBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: p.textPrimary),
                  title: Text('複製使用者 ID',
                      style: TextStyle(color: p.textPrimary)),
                  subtitle: Text(_user.id,
                      style: TextStyle(color: p.textMuted, fontSize: 12)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _user.id));
                    Navigator.of(menuCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已複製使用者 ID')),
                    );
                  },
                ),
                if (guild != null &&
                    widget.controller.vencord
                        .isPluginEnabled('PermissionsViewer')) ...[
                  Divider(height: 1, color: p.border),
                  ListTile(
                    leading: Icon(Icons.admin_panel_settings_outlined,
                        color: p.textPrimary),
                    title: Text('檢視成員權限 (Permissions)',
                        style: TextStyle(color: p.textPrimary)),
                    onTap: () {
                      Navigator.of(menuCtx).pop();
                      final refCh = (widget.controller.selectedChannel != null &&
                              !widget.controller.selectedChannel!.isDm)
                          ? widget.controller.selectedChannel!
                          : (guild.channels.isNotEmpty
                              ? guild.channels.first
                              : const DiscordChannel(
                                  id: '0', name: 'general', type: 0));
                      final memberPerms = DiscordPermissions.computeChannelPermissions(
                        guild: guild,
                        channel: refCh,
                        botUserId: _user.id,
                        botRoleIds: _member?.roleIds ?? const [],
                      );
                      showVencordPermissionsModal(
                        context,
                        palette: p,
                        title: _member?.effectiveName ?? _user.displayName,
                        permissions: memberPerms,
                      );
                    },
                  ),
                ],
                if (widget.controller.vencord.isPluginEnabled('ViewRaw')) ...[
                  Divider(height: 1, color: p.border),
                  ListTile(
                    leading: Icon(Icons.code_rounded, color: p.textPrimary),
                    title: Text('檢視原始資料 (View Raw)',
                        style: TextStyle(color: p.textPrimary)),
                    onTap: () {
                      Navigator.of(menuCtx).pop();
                      showVencordRawModal(
                        context,
                        palette: p,
                        title: 'User',
                        data: _user.toJson(),
                        sortKeys: widget.controller.vencord
                            .getSetting<bool>('ViewRaw', 'sortKeys', true),
                      );
                    },
                  ),
                ],
                if (guild != null && canKick) ...[
                  Divider(height: 1, color: p.border),
                  ListTile(
                    leading: const Icon(Icons.person_remove_outlined,
                        color: DiscordPalette.danger),
                    title: const Text(
                      '踢出伺服器',
                      style: TextStyle(color: DiscordPalette.danger),
                    ),
                    onTap: () async {
                      Navigator.of(menuCtx).pop();
                      try {
                        await widget.controller.rest
                            ?.kickMember(guild.id, _user.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('已將 ${_user.displayName} 踢出伺服器')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                  ),
                ],
                if (guild != null && canBan) ...[
                  Divider(height: 1, color: p.border),
                  ListTile(
                    leading: const Icon(Icons.gavel_rounded,
                        color: DiscordPalette.danger),
                    title: const Text(
                      '封鎖成員',
                      style: TextStyle(color: DiscordPalette.danger),
                    ),
                    onTap: () async {
                      Navigator.of(menuCtx).pop();
                      try {
                        await widget.controller.rest
                            ?.banMember(guild.id, _user.id);
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('已封鎖 ${_user.displayName}')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
    final eco = ctrl.ecoSettings.ecoPowerSaving;
    final sheetBg = p.profileBg;

    final acc = ctrl.activeAccount;
    final isSelf = acc != null && _user.id == acc.id;
    final guild =
        widget.guildId != null ? ctrl.findGuildById(widget.guildId) : null;

    final perms = ctrl.currentChannelPermissions();
    final isGuildOwner = guild != null && guild.ownerId == _user.id;
    final canKick = guild != null &&
        !isSelf &&
        !isGuildOwner &&
        DiscordPermissions.has(perms, DiscordPermissions.kickMembers);
    final canBan = guild != null &&
        !isSelf &&
        !isGuildOwner &&
        DiscordPermissions.has(perms, DiscordPermissions.banMembers);

    final allowAnim = !eco || ctrl.vencord.isPluginEnabled('AlwaysAnimate');
    final viewIcons = ctrl.vencord.isPluginEnabled('ViewIcons');
    final bannerUrl = isSelf
        ? (acc.bannerUrl(size: 600) ??
            _user.bannerUrl(size: 600, allowAnimated: allowAnim))
        : _user.bannerUrl(size: 600, allowAnimated: allowAnim);
    final accentInt = isSelf
        ? (acc.accentColor ?? _user.accentColor)
        : _user.accentColor;
    final bannerColor = accentInt != null
        ? Color(0xFF000000 | accentInt)
        : _deriveFallbackBannerColor(_user.id);

    final avatarUrl = _member != null
        ? _member!.effectiveAvatarUrl(widget.guildId, size: 128)
        : (isSelf ? acc.avatarUrl(size: 128) : _user.avatarUrl(size: 128));

    final effectiveDisplayName = _member?.effectiveName ??
        (isSelf ? acc.displayName : _user.displayName);
    final hasDistinctNick = _member?.nick != null &&
        _member!.nick!.isNotEmpty &&
        _member!.nick != _user.displayName;
    final subtitleText =
        hasDistinctNick ? '${_user.displayName} • ${_user.tag}' : _user.tag;

    final badges = isSelf ? acc.realBadges : _user.realBadges;
    final isBot = isSelf || _user.bot;
    final isVerifiedBot = isSelf ? acc.isVerifiedBot : _user.isVerifiedBot;

    final alreadyInThisDm = ctrl.selectedGuildId == null &&
        ctrl.selectedChannel?.dmRecipient?.id == _user.id;

    final createdDate = snowflakeCreatedAt(_user.id);
    final joinedDate = _member?.joinedAtDate;

    // Resolve sorted guild roles (excluding @everyone)
    final memberRoles = <DiscordRole>[];
    if (guild != null && _member != null) {
      for (final rId in _member!.roleIds) {
        if (rId == guild.id) continue;
        final r = guild.roles[rId];
        if (r != null) memberRoles.add(r);
      }
      memberRoles.sort((a, b) => b.position.compareTo(a.position));
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // 1. Banner + Close / More Actions + Overlapping Avatar
              SizedBox(
                height: 176,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: (viewIcons && bannerUrl != null)
                          ? () => showVencordImageViewerModal(
                                context,
                                palette: p,
                                title: '$effectiveDisplayName 橫幅',
                                imageUrl: bannerUrl,
                              )
                          : null,
                      child: Container(
                        height: 124,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: bannerColor,
                          image: bannerUrl != null
                              ? DecorationImage(
                                  image: NetworkImage(bannerUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                      ),
                    ),
                    // Top-left Close Button
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _bannerCircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    // Top-right More Actions Button (Copy ID / Moderation)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: _bannerCircleButton(
                        icon: Icons.more_horiz_rounded,
                        onTap: () => _showMoreActionsMenu(
                          context,
                          p: p,
                          guild: guild,
                          canKick: canKick,
                          canBan: canBan,
                        ),
                      ),
                    ),
                    // Overlapping Avatar
                    Positioned(
                      left: 16,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: viewIcons
                            ? () => showVencordImageViewerModal(
                                  context,
                                  palette: p,
                                  title: '$effectiveDisplayName 頭像',
                                  imageUrl: avatarUrl,
                                )
                            : null,
                        child: Stack(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: sheetBg,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 42,
                                backgroundImage: NetworkImage(avatarUrl),
                              ),
                            ),
                            if (isSelf)
                              Positioned(
                                right: 3,
                                bottom: 3,
                                child: DiscordStatusBadge(
                                  status: ctrl.botStatus,
                                  size: 25,
                                  borderColor: sheetBg,
                                  borderWidth: 4.5,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // 2. Identity, Badges & Action Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          effectiveDisplayName,
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (isBot)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: DiscordPalette.blurple,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isVerifiedBot) ...[
                                  const Icon(Icons.check_rounded,
                                      size: 12, color: Colors.white),
                                  const SizedBox(width: 2),
                                ],
                                const Text(
                                  'APP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitleText,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 14,
                      ),
                    ),

                    // Real Discord Badges (ONLY if earned!)
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: p.cardBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Wrap(
                          spacing: 6,
                          children: badges.map((b) {
                            return Tooltip(
                              message: b.description,
                              child: Image.network(
                                b.iconUrl,
                                width: 20,
                                height: 20,
                                cacheWidth: 40,
                                errorBuilder: (_, __, ___) =>
                                    const SizedBox.shrink(),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Primary Discord Profile Action Bar
                    Row(
                      children: [
                        if (isSelf)
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: DiscordPalette.blurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(21),
                                  ),
                                ),
                                onPressed: () =>
                                    showDiscordStatusSheet(context, ctrl),
                                icon: const Icon(Icons.edit_rounded,
                                    size: 17, color: Colors.white),
                                label: const Text(
                                  '變更狀態與活動',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else if (!isBot)
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: alreadyInThisDm
                                      ? p.elevatedBg
                                      : DiscordPalette.blurple,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(21),
                                  ),
                                ),
                                onPressed: _openingDm
                                    ? null
                                    : () async {
                                        if (alreadyInThisDm) {
                                          Navigator.of(context).pop();
                                          return;
                                        }
                                        setState(() => _openingDm = true);
                                        try {
                                          await ctrl.openDmWithUser(_user.id);
                                          if (context.mounted) {
                                            Navigator.of(context).pop();
                                            widget.onNavigateToDm?.call();
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            setState(() => _openingDm = false);
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(content: Text('$e')),
                                            );
                                          }
                                        }
                                      },
                                icon: _openingDm
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Icon(
                                        Icons.chat_bubble_rounded,
                                        size: 17,
                                        color: alreadyInThisDm
                                            ? p.textPrimary
                                            : Colors.white,
                                      ),
                                label: Text(
                                  alreadyInThisDm ? '返回私訊對話' : '傳送訊息',
                                  style: TextStyle(
                                    color: alreadyInThisDm
                                        ? p.textPrimary
                                        : Colors.white,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: p.elevatedBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(21),
                                  ),
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                      ClipboardData(text: _user.id));
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('已複製機器人 ID')),
                                  );
                                },
                                icon: Icon(Icons.copy_rounded,
                                    size: 17, color: p.textPrimary),
                                label: Text(
                                  '複製機器人 ID',
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Bio Card (for own Bot if description/bio exists)
                    if (isSelf && acc.bio != null && acc.bio!.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: p.sidebarBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border, width: 0.7),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '簡介',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              acc.bio!,
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 14,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Member Since Card (Discord Creation Date + Server Join Date)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: p.sidebarBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border, width: 0.7),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '加入時間',
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DiscordClydeLogo(
                                    size: 16,
                                    color: p.textSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _formatDateZh(createdDate),
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              if (guild != null && joinedDate != null)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (guild.iconUrl(size: 32) != null)
                                      ClipOval(
                                        child: Image.network(
                                          guild.iconUrl(size: 32)!,
                                          width: 16,
                                          height: 16,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    else
                                      Icon(Icons.dns_rounded,
                                          size: 15, color: p.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      _formatDateZh(joinedDate),
                                      style: TextStyle(
                                        color: p.textPrimary,
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Server Roles Card (when inside a Guild and member has roles)
                    if (memberRoles.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: p.sidebarBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border, width: 0.7),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '身分組',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: memberRoles.map((role) {
                                final dotColor = role.color != 0
                                    ? Color(0xFF000000 | role.color)
                                    : const Color(0xFF99AAB5);
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: p.cardBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: p.border, width: 0.8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: dotColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        role.name,
                                        style: TextStyle(
                                          color: p.textPrimary,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bannerCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: Color(0x88000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}
