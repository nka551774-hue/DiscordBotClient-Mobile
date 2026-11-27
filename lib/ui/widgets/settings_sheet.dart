import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';
import 'vencord_sheets.dart';

/// Clean, authentic Discord Mobile "You" Profile Modal Sheet —
/// renders ONLY real account data (real banner/accentColor, real Discord badges
/// from publicFlags/applicationFlags, real bot description, real creation date)
/// without any hardcoded user-specific profile decorations!
void showYouProfileModal(
  BuildContext context,
  BotClientController controller,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _YouProfileModalSheet(controller: controller),
  );
}

/// Official mobile "You" tab: same content as the profile sheet, embedded full-page.
class YouProfilePage extends StatelessWidget {
  final BotClientController controller;

  const YouProfilePage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) =>
      _YouProfileModalSheet(controller: controller, embedded: true);
}

class _YouProfileModalSheet extends StatelessWidget {
  final BotClientController controller;
  final bool embedded;

  const _YouProfileModalSheet({required this.controller, this.embedded = false});

  Color _deriveFallbackBannerColor(String id) {
    const palette = [
      Color(0xFF5865F2),
      Color(0xFF3B4252),
      Color(0xFF2B5B84),
      Color(0xFF237A57),
      Color(0xFF5E3B76),
    ];
    final idx = (int.tryParse(id.substring(id.length.clamp(0, 4) > 3 ? id.length - 3 : 0)) ?? 0) %
        palette.length;
    return palette[idx];
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final acc = controller.activeAccount;
        if (acc == null) return const SizedBox.shrink();

        final p = DiscordPalette(oled: controller.ecoSettings.oledBlackMode);
        final sheetBg = p.profileBg;
        final bannerColor = acc.accentColor != null
            ? Color(0xFF000000 | acc.accentColor!)
            : _deriveFallbackBannerColor(acc.id);
        final bannerUrl = acc.bannerUrl(size: 1024);
        final badges = acc.realBadges;

        final created = snowflakeCreatedAt(acc.id);
        final createdStr =
            '${created.year}年${created.month}月${created.day}日';

        final height =
            embedded ? null : MediaQuery.of(context).size.height * 0.90;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: embedded
                ? BorderRadius.zero
                : const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            padding: const EdgeInsets.only(bottom: 36),
            children: [
              // 1. Banner + Top Bar Controls + Overlapping Avatar + Status Thought Bubble
              SizedBox(
                height: 184,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    GestureDetector(
                      onTap: (controller.vencord.isPluginEnabled('ViewIcons') &&
                              bannerUrl != null)
                          ? () => showVencordImageViewerModal(
                                context,
                                palette: p,
                                title: '${acc.displayName} 橫幅',
                                imageUrl: bannerUrl,
                              )
                          : null,
                      // Re-fetch /users/{id}: the stored login snapshot may predate a banner change.
                      child: FutureBuilder<(DiscordUser?, DiscordMember?)>(
                        future: controller.fetchRichUserProfile(acc.id),
                        builder: (_, snap) => DiscordBannerImage(
                          url: snap.data?.$1?.bannerUrl(size: 1024) ??
                              bannerUrl,
                          color: bannerColor,
                          height: 132,
                        ),
                      ),
                    ),

                    // Top-left Close Button
                    if (!embedded)
                    Positioned(
                      top: 14,
                      left: 14,
                      child: _bannerCircleButton(
                        icon: Icons.close_rounded,
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),

                    // Top-right Switch Accounts & Settings Gear (Standard Discord Mobile)
                    Positioned(
                      top: 14,
                      right: 14,
                      child: Row(
                        children: [
                          _bannerCircleButton(
                            icon: Icons.swap_horiz_rounded,
                            onTap: () =>
                                showSwitchAccountsSheet(context, controller),
                          ),
                          const SizedBox(width: 8),
                          _bannerCircleButton(
                            icon: Icons.settings_rounded,
                            onTap: () {
                              if (!embedded) Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DiscordSettingsScreen(
                                      controller: controller),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Overlapping Avatar + Status Badge
                    Positioned(
                      left: 16,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: () =>
                            showDiscordStatusSheet(context, controller),
                        onLongPress: controller.vencord
                                .isPluginEnabled('ViewIcons')
                            ? () => showVencordImageViewerModal(
                                  context,
                                  palette: p,
                                  title: '${acc.displayName} 頭像',
                                  imageUrl: acc.avatarUrl(size: 1024),
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
                                backgroundImage: NetworkImage(
                                  acc.avatarUrl(size: 128),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 3,
                              bottom: 3,
                              child: DiscordStatusBadge(
                                status: controller.botStatus,
                                size: 26,
                                borderColor: sheetBg,
                                borderWidth: 4.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Discord Thought-Bubble Custom Status Pill
                    Positioned(
                      left: 108,
                      top: 108,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: p.cardBg,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 118,
                      top: 116,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: p.cardBg,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 112,
                      bottom: 6,
                      right: 18,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () =>
                              showDiscordStatusSheet(context, controller),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 9),
                            decoration: BoxDecoration(
                              color: p.cardBg,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: p.border, width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  controller.botActivityName.isEmpty
                                      ? Icons.add_circle_rounded
                                      : Icons.chat_bubble_outline_rounded,
                                  size: 16,
                                  color: p.textSecondary,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    controller.botActivityName.isEmpty
                                        ? '新增狀態'
                                        : controller.botActivityName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: controller.botActivityName.isEmpty
                                          ? p.textSecondary
                                          : p.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 2. Identity, Official APP Badge, Real Badges (only if earned!)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () =>
                          showSwitchAccountsSheet(context, controller),
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          Text(
                            acc.displayName,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          // Official Discord APP / Verified APP Pill
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
                                if (acc.isVerifiedBot) ...[
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
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: p.textSecondary,
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      acc.tag,
                      style: TextStyle(
                        color: p.textSecondary,
                        fontSize: 14.5,
                      ),
                    ),

                    // Real Discord Badges from UserBadges.ts (ONLY shown if account actually has badges!)
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

                    // Edit Status / Presence Button
                    SizedBox(
                      width: double.infinity,
                      height: 42,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: DiscordPalette.blurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(21),
                          ),
                        ),
                        onPressed: () =>
                            showDiscordStatusSheet(context, controller),
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
                    const SizedBox(height: 18),

                    // Overview Card (Bio + Member Since, matching standard Discord Mobile Profile)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: p.sidebarBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border, width: 0.7),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (acc.bio != null && acc.bio!.isNotEmpty) ...[
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
                                fontSize: 14.5,
                                height: 1.45,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1, color: p.border),
                            ),
                          ],
                          Text(
                            'Discord 加入時間',
                            style: TextStyle(
                              color: p.textSecondary,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            createdStr,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 14.5,
                            ),
                          ),
                          if (controller.totalShards > 1) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(height: 1, color: p.border),
                            ),
                            Text(
                              '分片連線 (Shard)',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Shard ${controller.currentShard} / ${controller.totalShards}',
                              style: TextStyle(
                                color: p.textPrimary,
                                fontSize: 14.5,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Copy Bot ID Tile
                    Container(
                      decoration: BoxDecoration(
                        color: p.sidebarBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: p.border, width: 0.7),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.badge_outlined,
                            color: p.textSecondary, size: 20),
                        title: Text('複製應用程式 / 機器人 ID',
                            style:
                                TextStyle(color: p.textPrimary, fontSize: 14.5)),
                        subtitle: Text(acc.id,
                            style:
                                TextStyle(color: p.textMuted, fontSize: 12)),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: acc.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已複製 ID'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
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

  Widget _bannerCircleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0x70000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

/// Official Discord Mobile "設定" (Settings) screen.
class DiscordSettingsScreen extends StatelessWidget {
  final BotClientController controller;

  const DiscordSettingsScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final eco = controller.ecoSettings;
        final p = DiscordPalette(oled: eco.oledBlackMode);
        final acc = controller.activeAccount;

        return Scaffold(
          backgroundColor: p.profileBg,
          appBar: AppBar(
            backgroundColor: p.profileBg,
            title: const Text('設定'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _groupLabel(p, '帳號設定'),
              _settingsGroup(p, [
                ListTile(
                  leading:
                      Icon(Icons.swap_horiz_rounded, color: p.textSecondary),
                  title: Text('切換帳號',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  trailing:
                      Icon(Icons.chevron_right, color: p.textMuted, size: 20),
                  onTap: () => showSwitchAccountsSheet(context, controller),
                ),
              ]),
              const SizedBox(height: 20),
              _groupLabel(p, '應用程式設定'),
              _settingsGroup(p, [
                ListTile(
                  leading:
                      Icon(Icons.dark_mode_outlined, color: p.textSecondary),
                  title: Text('外觀主題',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    eco.oledBlackMode ? 'Onyx (純黑)' : 'Ash (深灰)',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  trailing: Switch(
                    value: eco.oledBlackMode,
                    onChanged: (v) => controller.updateEcoSettings(
                      eco.copyWith(oledBlackMode: v),
                    ),
                  ),
                ),
                Divider(height: 1, color: p.border),
                SwitchListTile(
                  secondary: Icon(Icons.bolt_outlined, color: p.textSecondary),
                  title: Text('省電模式',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    '背景閒置時自動休眠連線並降低記憶體快取',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  value: eco.ecoPowerSaving,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(ecoPowerSaving: v),
                    reconnectGateway: true,
                  ),
                ),
              ]),
              const SizedBox(height: 20),
              _groupLabel(p, 'Vencord'),
              _settingsGroup(p, [
                ListTile(
                  leading:
                      Icon(Icons.extension_rounded, color: p.brandColor),
                  title: Text('Vencord 插件 (Plugins)',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    '已啟用 ${controller.vencord.allPlugins.where((pl) => controller.vencord.isPluginEnabled(pl.name)).length} / ${controller.vencord.allPlugins.length} 個內建與自訂外掛',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, color: p.textMuted, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VencordSettingsScreen(
                          controller: controller,
                          initialTabIndex: 0,
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: p.border),
                ListTile(
                  leading: Icon(Icons.palette_outlined, color: p.textSecondary),
                  title: Text('Vencord 主題與 QuickCSS',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    'Online Themes 連結與 CSS 變數即時套用',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, color: p.textMuted, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VencordSettingsScreen(
                          controller: controller,
                          initialTabIndex: 1,
                        ),
                      ),
                    );
                  },
                ),
                Divider(height: 1, color: p.border),
                ListTile(
                  leading:
                      Icon(Icons.sync_alt_rounded, color: p.textSecondary),
                  title: Text('Vencord 設定備份與同步',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    '相容電腦版 vencord-settings-backup.json 匯出與匯入',
                    style: TextStyle(color: p.textMuted, fontSize: 12.5),
                  ),
                  trailing:
                      Icon(Icons.chevron_right, color: p.textMuted, size: 20),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => VencordSettingsScreen(
                          controller: controller,
                          initialTabIndex: 2,
                        ),
                      ),
                    );
                  },
                ),
              ]),
              const SizedBox(height: 20),
              _groupLabel(p, 'Gateway Intents'),
              _settingsGroup(p, [
                SwitchListTile(
                  title: Text('Message Content Intent',
                      style: TextStyle(color: p.textPrimary, fontSize: 14.5)),
                  subtitle: acc != null && !acc.hasMessageContentIntent
                      ? const Text(
                          'Developer Portal 尚未開啟此權限',
                          style: TextStyle(
                              color: DiscordPalette.yellow, fontSize: 12),
                        )
                      : null,
                  value: eco.enableMessageContentIntent,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(enableMessageContentIntent: v),
                    reconnectGateway: true,
                  ),
                ),
                Divider(height: 1, color: p.border),
                SwitchListTile(
                  title: Text('Server Members Intent',
                      style: TextStyle(color: p.textPrimary, fontSize: 14.5)),
                  value: eco.enableMembersIntent,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(enableMembersIntent: v),
                    reconnectGateway: true,
                  ),
                ),
                Divider(height: 1, color: p.border),
                SwitchListTile(
                  title: Text('Presence Intent',
                      style: TextStyle(color: p.textPrimary, fontSize: 14.5)),
                  value: eco.enablePresenceIntent,
                  onChanged: (v) => controller.updateEcoSettings(
                    eco.copyWith(enablePresenceIntent: v),
                    reconnectGateway: true,
                  ),
                ),
              ]),
              const SizedBox(height: 24),
              _settingsGroup(p, [
                ListTile(
                  leading: const Icon(Icons.logout_rounded,
                      color: DiscordPalette.danger),
                  title: const Text(
                    '登出',
                    style: TextStyle(
                      color: DiscordPalette.danger,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(context).pop();
                    await controller.logoutCurrentAccount();
                  },
                ),
              ]),
            ],
          ),
        );
      },
    );
  }

  Widget _groupLabel(DiscordPalette p, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: p.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _settingsGroup(DiscordPalette p, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: p.sidebarBg,
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// Official Discord Mobile Status & Custom Status Editor Sheet.
void showDiscordStatusSheet(
  BuildContext context,
  BotClientController controller,
) {
  final p = DiscordPalette(oled: controller.ecoSettings.oledBlackMode);
  final activityCtrl =
      TextEditingController(text: controller.botActivityName);
  String status = controller.botStatus;
  int activityType = controller.botActivityType;

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: p.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    '設定狀態',
                    style: TextStyle(
                      color: p.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    color: p.sidebarBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      _statusTile(
                        p,
                        label: '線上',
                        value: 'online',
                        current: status,
                        onTap: () => setModalState(() => status = 'online'),
                      ),
                      Divider(height: 1, color: p.border),
                      _statusTile(
                        p,
                        label: '閒置',
                        value: 'idle',
                        current: status,
                        onTap: () => setModalState(() => status = 'idle'),
                      ),
                      Divider(height: 1, color: p.border),
                      _statusTile(
                        p,
                        label: '請勿打擾',
                        value: 'dnd',
                        current: status,
                        onTap: () => setModalState(() => status = 'dnd'),
                      ),
                      Divider(height: 1, color: p.border),
                      _statusTile(
                        p,
                        label: '隱形',
                        value: 'invisible',
                        current: status,
                        onTap: () => setModalState(() => status = 'invisible'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.sidebarBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      DropdownButton<int>(
                        value: activityType,
                        underline: const SizedBox.shrink(),
                        dropdownColor: p.cardBg,
                        style: TextStyle(color: p.textPrimary, fontSize: 13.5),
                        items: const [
                          DropdownMenuItem(value: 4, child: Text('自訂狀態')),
                          DropdownMenuItem(value: 0, child: Text('正在玩')),
                          DropdownMenuItem(value: 2, child: Text('正在聽')),
                          DropdownMenuItem(value: 3, child: Text('正在看')),
                          DropdownMenuItem(value: 5, child: Text('正在競爭')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setModalState(() => activityType = v);
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: activityCtrl,
                          style: TextStyle(color: p.textPrimary, fontSize: 14),
                          decoration: InputDecoration(
                            hintText: '輸入狀態文字...',
                            hintStyle:
                                TextStyle(color: p.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (activityCtrl.text.isNotEmpty)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.clear_rounded,
                              size: 18, color: p.textMuted),
                          onPressed: () =>
                              setModalState(() => activityCtrl.clear()),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: DiscordPalette.blurple,
                    ),
                    onPressed: () {
                      controller.updateBotPresence(
                        status: status,
                        activityType: activityType,
                        activityName: activityCtrl.text,
                      );
                      Navigator.of(ctx).pop();
                    },
                    child: const Text('儲存'),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

Widget _statusTile(
  DiscordPalette p, {
  required String label,
  required String value,
  required String current,
  required VoidCallback onTap,
}) {
  final selected = current == value;
  return ListTile(
    onTap: onTap,
    leading: DiscordStatusBadge(
      status: value,
      size: 16,
      borderColor: p.sidebarBg,
      borderWidth: 2,
    ),
    title: Text(label, style: TextStyle(color: p.textPrimary, fontSize: 15)),
    trailing: Icon(
      selected ? Icons.radio_button_checked : Icons.radio_button_off,
      color: selected ? DiscordPalette.blurple : p.textMuted,
      size: 20,
    ),
  );
}

/// Official Discord Mobile "切換帳號" (Switch Accounts) bottom sheet.
void showSwitchAccountsSheet(
  BuildContext context,
  BotClientController controller,
) {
  final p = DiscordPalette(oled: controller.ecoSettings.oledBlackMode);
  showModalBottomSheet<void>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '切換帳號',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: p.sidebarBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: controller.savedAccounts.map((acc) {
                    final active = acc.id == controller.activeAccount?.id;
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundImage:
                            NetworkImage(acc.avatarUrl(size: 64)),
                      ),
                      title: Text(
                        acc.displayName,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(acc.tag,
                          style: TextStyle(color: p.textMuted, fontSize: 12)),
                      trailing: active
                          ? const Icon(Icons.check_circle,
                              color: DiscordPalette.blurple, size: 20)
                          : null,
                      onTap: active
                          ? null
                          : () async {
                              Navigator.of(ctx).pop();
                              if (Navigator.of(context).canPop()) {
                                Navigator.of(context).pop();
                              }
                              await controller.loginWithToken(
                                acc.token,
                                silentAccountSwitch: true,
                              );
                            },
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    }
                    await controller.logoutCurrentAccount();
                  },
                  child: const Text('新增帳號'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
