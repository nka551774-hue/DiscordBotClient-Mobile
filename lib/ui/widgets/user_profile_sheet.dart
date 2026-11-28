import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';
import 'member_moderation.dart';
import 'settings_sheet.dart';
import 'vencord_sheets.dart';
import '../../l10n/strings.dart';

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
/// Look up any user by ID, mention (<@id>) or discord.com/users/<id> link.
Future<void> showUserLookupDialog(
  BuildContext context,
  BotClientController controller, {
  VoidCallback? onNavigateToDm,
}) async {
  final textCtrl = TextEditingController();
  final input = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tr('查詢使用者')),
      content: TextField(
        controller: textCtrl,
        autofocus: true,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          hintText: tr('使用者 ID、提及或個人資料連結'),
        ),
        onSubmitted: (v) => Navigator.of(ctx).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(tr('取消')),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(textCtrl.text),
          child: Text(tr('查詢')),
        ),
      ],
    ),
  );
  // No dispose: the dialog's field still uses it during the close animation.
  if (input == null || !context.mounted) return;
  final id = RegExp(r'\d{15,21}').firstMatch(input)?.group(0);
  final messenger = ScaffoldMessenger.of(context);
  if (id == null) {
    messenger.showSnackBar(
        SnackBar(content: Text(tr('請輸入有效的使用者 ID'))));
    return;
  }
  final (user, _) = await controller.fetchRichUserProfile(id);
  if (!context.mounted) return;
  if (user == null) {
    messenger.showSnackBar(SnackBar(content: Text(tr('找不到此使用者'))));
    return;
  }
  await showUserProfileById(
    context,
    controller: controller,
    userId: id,
    guildId: controller.selectedGuildId,
    onNavigateToDm: onNavigateToDm,
  );
}

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
      trf('{0}年{1}月{2}日', [dt.year, dt.month, dt.day]);

  void _showMoreActionsMenu(
    BuildContext context, {
    required DiscordPalette p,
    required DiscordGuild? guild,
  }) {
    showModalBottomSheet<void>(
      context: context,
      builder: (menuCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: p.elevatedBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: p.textPrimary),
                  title: Text(tr('複製使用者 ID'),
                      style: TextStyle(color: p.textPrimary)),
                  subtitle: Text(_user.id,
                      style: TextStyle(color: p.textMuted, fontSize: 12)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: _user.id));
                    Navigator.of(menuCtx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('已複製使用者 ID'))),
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
                    title: Text(tr('檢視成員權限 (Permissions)'),
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
                    title: Text(tr('檢視原始資料 (View Raw)'),
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
                if (guild != null)
                  ...memberModerationTiles(
                    context: context,
                    menuCtx: menuCtx,
                    controller: widget.controller,
                    guild: guild,
                    user: _user,
                    member: _member,
                    p: p,
                    onRemoved: () {
                      if (context.mounted) Navigator.of(context).pop();
                    },
                  ),
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


    final allowAnim = !eco || ctrl.vencord.isPluginEnabled('AlwaysAnimate');
    final viewIcons = ctrl.vencord.isPluginEnabled('ViewIcons');
    final bannerUrl =
        _member?.guildBannerUrl(widget.guildId, allowAnimated: allowAnim) ??
            _user.bannerUrl(size: 1024, allowAnimated: allowAnim) ??
            (isSelf ? acc.bannerUrl(size: 1024) : null);
    final accentInt = isSelf
        ? (acc.accentColor ?? _user.accentColor)
        : _user.accentColor;
    final extras = isSelf ? null : ctrl.profileExtras(_user.id);
    final bannerColor = (extras?.themeColors.isNotEmpty ?? false)
        ? Color(0xFF000000 | extras!.themeColors.first)
        : accentInt != null
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
    final pronouns = extras?.pronouns;
    final subtitleText = [
      hasDistinctNick ? '${_user.displayName} • ${_user.tag}' : _user.tag,
      if (pronouns != null && pronouns.isNotEmpty) pronouns,
    ].join(' • ');
    final otherBio = extras?.bio;

    // Bots can't read premium_type; only Nitro users can set a profile banner,
    // an animated avatar or per-server avatar/banner, so those prove Nitro.
    final hasNitro = !_user.bot &&
        (_user.banner != null ||
            (_user.avatar?.startsWith('a_') ?? false) ||
            _member?.guildAvatar != null ||
            _member?.guildBanner != null);
    final boostSince = (_member?.premiumSince != null
            ? DateTime.tryParse(_member!.premiumSince!)
            : null) ??
        ctrl.boostingSince(_user.id);
    final ageBadge = (!_user.bot && !isSelf)
        ? DiscordBadgeInfo.accountAge(snowflakeCreatedAt(_user.id))
        : null;
    // Official order: Nitro, booster, then flag badges.
    final badges = [
      if (hasNitro || boostSince != null)
        DiscordBadgeInfo(
          id: 'premium',
          description: tr('Nitro 會員'),
          iconHash: '2ba85e8026a8614b640c2837bcdfe21b',
        ),
      if (boostSince != null) DiscordBadgeInfo.booster(boostSince),
      ...(isSelf ? acc.realBadges : _user.realBadges),
      if (ageBadge != null) ageBadge,
    ];
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

    // Official BANNER_ASPECT_RATIO 2.86.
    final bannerHeight = MediaQuery.of(context).size.width / 2.86;

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
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              // 1. Banner + Close / More Actions + Overlapping Avatar
              SizedBox(
                height: bannerHeight + 46,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: (viewIcons && bannerUrl != null)
                          ? () => showVencordImageViewerModal(
                                context,
                                palette: p,
                                title: trf('{0} 橫幅', [effectiveDisplayName]),
                                imageUrl: bannerUrl,
                              )
                          : null,
                      child: DiscordBannerImage(
                        url: bannerUrl,
                        color: bannerColor,
                        height: bannerHeight,
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
                                  title: trf('{0} 頭像', [effectiveDisplayName]),
                                  imageUrl: avatarUrl,
                                )
                            : null,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: sheetBg,
                                shape: BoxShape.circle,
                              ),
                              child: CircleAvatar(
                                radius: 40,
                                backgroundImage: NetworkImage(avatarUrl),
                              ),
                            ),
                            if (_user.avatarDecorationUrl != null)
                              Positioned(
                                left: -4,
                                top: -4,
                                width: 100,
                                height: 100,
                                child: IgnorePointer(
                                  child: Image.network(
                                    _user.avatarDecorationUrl!,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
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
                        if (!isSelf && _user.guildTag != null)
                          DiscordGuildTagPill(
                            tag: _user.guildTag!,
                            badgeUrl: _user.guildTagBadgeUrl,
                            fontSize: 13,
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
                              child: DiscordBadgeIcon(b.iconUrl),
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
                                label: Text(
                                  tr('變更狀態與活動'),
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
                                  alreadyInThisDm ? tr('返回私訊對話') : tr('傳送訊息'),
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
                                    SnackBar(
                                        content: Text(tr('已複製機器人 ID'))),
                                  );
                                },
                                icon: Icon(Icons.copy_rounded,
                                    size: 17, color: p.textPrimary),
                                label: Text(
                                  tr('複製機器人 ID'),
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
                    if ((isSelf && acc.bio != null && acc.bio!.isNotEmpty) ||
                        (otherBio != null && otherBio.isNotEmpty)) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: p.elevatedBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border, width: 0.7),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('簡介'),
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isSelf ? acc.bio! : otherBio!,
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
                        color: p.elevatedBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border, width: 0.7),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('加入時間'),
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
                          color: p.elevatedBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.border, width: 0.7),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('身分組'),
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

                    const SizedBox(height: 12),
                    _userDataCard(
                      context,
                      p,
                      ctrl: ctrl,
                      guild: guild,
                      isSelf: isSelf,
                      createdDate: createdDate,
                      joinedDate: joinedDate,
                      accentInt: accentInt,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDateTime(DateTime dt) {
    final l = dt.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${l.year}/${two(l.month)}/${two(l.day)} ${two(l.hour)}:${two(l.minute)}';
  }

  /// Every field the bot API returns for this user / member.
  Widget _userDataCard(
    BuildContext context,
    DiscordPalette p, {
    required BotClientController ctrl,
    required DiscordGuild? guild,
    required bool isSelf,
    required DateTime createdDate,
    required DateTime? joinedDate,
    required int? accentInt,
  }) {
    final rows = <(String, String, Widget?)>[
      (tr('使用者 ID'), _user.id, null),
      (tr('使用者名稱'), _user.tag, null),
      (tr('帳號建立時間'), _fmtDateTime(createdDate), null),
      (
        tr('帳號類型'),
        _user.system
            ? tr('系統')
            : (_user.bot || isSelf)
                ? tr('機器人')
                : tr('使用者'),
        null
      ),
      if (accentInt != null)
        (
          tr('強調色'),
          '#${accentInt.toRadixString(16).padLeft(6, '0').toUpperCase()}',
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: Color(0xFF000000 | accentInt),
              shape: BoxShape.circle,
            ),
          ),
        ),
      if (_user.guildTag != null)
        (
          tr('伺服器標籤'),
          '${_user.guildTag} · ${ctrl.findGuildById(_user.guildTagGuildId)?.name ?? _user.guildTagGuildId ?? ''}',
          null
        ),
      if (_member != null && guild != null) ...[
        if (_member!.nick != null && _member!.nick!.isNotEmpty)
          (tr('伺服器暱稱'), _member!.nick!, null),
        if (joinedDate != null)
          (tr('加入伺服器'), _fmtDateTime(joinedDate), null),
        if (_member!.premiumSince != null)
          (
            tr('伺服器加成開始'),
            _fmtDateTime(DateTime.parse(_member!.premiumSince!)),
            null
          ),
        if (_member!.timeoutUntil != null &&
            DateTime.parse(_member!.timeoutUntil!).isAfter(DateTime.now()))
          (
            tr('禁言至'),
            _fmtDateTime(DateTime.parse(_member!.timeoutUntil!)),
            null
          ),
      ],
    ];
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(15, 13, 15, 8),
      decoration: BoxDecoration(
        color: p.elevatedBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border, width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('使用者資料'),
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          for (final r in rows)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: r.$2));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(trf('已複製{0}', [r.$1])),
                  duration: const Duration(seconds: 1),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 104,
                      child: Text(
                        r.$1,
                        style: TextStyle(color: p.textMuted, fontSize: 13),
                      ),
                    ),
                    if (r.$3 != null) ...[r.$3!, const SizedBox(width: 6)],
                    Expanded(
                      child: Text(
                        r.$2,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (!isSelf && ctrl.profileEndpointDenied)
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                tr('機器人帳號無法取得簡介 / 代名詞'),
                style: TextStyle(color: p.textMuted, fontSize: 12),
              ),
            ),
        ],
      ),
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
