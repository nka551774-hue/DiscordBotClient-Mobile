import 'package:flutter/material.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';

/// 1:1 recreation of Screenshot 1 (media_1795696333975_c51ef427.jpg):
/// Latest 2025/2026 Discord Mobile Modal "You" Profile Sheet with:
/// - Banner + top-left rounded X close button
/// - Overlapping Avatar with Status Badge + Thought-Bubble "+ 新增狀態" pill
/// - Username + chevron (Switch Accounts) + tag pill + Badges row
/// - Full-width Blurple "編輯個人資料" button
/// - 4 Sub-tabs: 首頁 | 公告欄 | 動態 | 願望清單
/// - "Orbs 餘額" card & "簡介" section
/// - Floating 4-icon bottom dock: 任務 | 商店 | Nitro | 設定
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

class _YouProfileModalSheet extends StatefulWidget {
  final BotClientController controller;

  const _YouProfileModalSheet({required this.controller});

  @override
  State<_YouProfileModalSheet> createState() => _YouProfileModalSheetState();
}

class _YouProfileModalSheetState extends State<_YouProfileModalSheet> {
  int _subTab = 0;

  static String statusLabelZh(String st) {
    switch (st) {
      case 'idle':
        return '閒置';
      case 'dnd':
        return '請勿打擾';
      case 'invisible':
        return '隱形';
      default:
        return '線上';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final ctrl = widget.controller;
        final acc = ctrl.activeAccount;
        if (acc == null) return const SizedBox.shrink();

        final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
        final sheetBg = p.profileBg;
        final bannerColor = acc.accentColor != null
            ? Color(0xFF000000 | acc.accentColor!)
            : const Color(0xFFCAA43B); // Warm Discord gold matching Screenshot 1
        final bannerUrl = acc.bannerUrl(size: 600);

        final created = snowflakeCreatedAt(acc.id);
        final createdStr =
            '${created.year}年${created.month}月${created.day}日';

        final height = MediaQuery.of(context).size.height * 0.93;

        return Container(
          height: height,
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Main Scrollable Profile Content
              ListView(
                padding: const EdgeInsets.only(bottom: 110),
                children: [
                  // 1. Top Banner + Overlapping Avatar + Thought-Bubble Status Pill
                  SizedBox(
                    height: 184,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Banner
                        Container(
                          height: 132,
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

                        // Top-left Rounded Close X Button (matching Screenshot 1)
                        Positioned(
                          top: 14,
                          left: 14,
                          child: GestureDetector(
                            onTap: () => Navigator.of(context).pop(),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0x66000000),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),

                        // Overlapping Avatar + Status Badge
                        Positioned(
                          left: 16,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () =>
                                showDiscordStatusSheet(context, ctrl),
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
                                    status: ctrl.botStatus,
                                    size: 26,
                                    borderColor: sheetBg,
                                    borderWidth: 4.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Thought-bubble dots + Custom Status Pill ("+ 新增狀態...")
                        Positioned(
                          left: 108,
                          top: 108,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E1F26),
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
                            decoration: const BoxDecoration(
                              color: Color(0xFF1E1F26),
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
                                  showDiscordStatusSheet(context, ctrl),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 13, vertical: 9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1F26),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                      color: const Color(0xFF2B2D36),
                                      width: 0.8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.add_circle_rounded,
                                      size: 17,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 7),
                                    Flexible(
                                      child: Text(
                                        ctrl.botActivityName.isEmpty
                                            ? '新增狀態'
                                            : ctrl.botActivityName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: p.textPrimary,
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

                  // 2. Identity, Tag Pill & Badges Strip
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // DisplayName + Chevron -> Switch Accounts
                        GestureDetector(
                          onTap: () =>
                              showSwitchAccountsSheet(context, ctrl),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  acc.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 23,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: p.textSecondary,
                                size: 22,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Username + Tag Pill
                        Row(
                          children: [
                            Text(
                              acc.username,
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 14.5,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1F26),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFF2B2D36),
                                    width: 0.6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.bolt_rounded,
                                    size: 13,
                                    color: Color(0xFFB784F7),
                                  ),
                                  SizedBox(width: 3),
                                  Text(
                                    'BOT',
                                    style: TextStyle(
                                      color: Color(0xFFE3E5E8),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Badges Pill Row
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1B22),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.speed_rounded,
                                  size: 16, color: Color(0xFF8EA1E1)),
                              SizedBox(width: 7),
                              Icon(Icons.sports_esports_rounded,
                                  size: 16, color: Color(0xFFF0B232)),
                              SizedBox(width: 7),
                              Icon(Icons.code_rounded,
                                  size: 16, color: Color(0xFF23A55A)),
                              SizedBox(width: 7),
                              Icon(Icons.verified_rounded,
                                  size: 16, color: Color(0xFF5865F2)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // 3. Full-Width Blurple "編輯個人資料" Button
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: DiscordPalette.blurple,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            onPressed: () =>
                                showDiscordStatusSheet(context, ctrl),
                            icon: const Icon(Icons.edit_rounded,
                                size: 17, color: Colors.white),
                            label: const Text(
                              '編輯個人資料',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Four Sub-Tabs: 首頁 | 公告欄 | 動態 | 願望清單
                  Container(
                    decoration: BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: p.border, width: 1)),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildProfileSubTab('首頁', 0, p),
                        _buildProfileSubTab('公告欄', 1, p),
                        _buildProfileSubTab('動態', 2, p),
                        _buildProfileSubTab('願望清單', 3, p),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. Sub-Tab Body Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: _subTab == 0
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Orbs 餘額 Card (matching Screenshot 1)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF16171D),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: const Color(0xFF22232B),
                                      width: 0.7),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      'Orbs 餘額',
                                      style: TextStyle(
                                        color: p.textPrimary,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.more_horiz_rounded,
                                      color: p.textSecondary,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),

                              // 簡介 (About Me)
                              Text(
                                '簡介',
                                style: TextStyle(
                                  color: p.textSecondary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                (acc.bio != null && acc.bio!.isNotEmpty)
                                    ? acc.bio!
                                    : 'Discord 機器人帳號 • 目前狀態：${statusLabelZh(ctrl.botStatus)}\n加入 Discord 時間：$createdStr\n已連線伺服器數量：${ctrl.guilds.length}',
                                style: TextStyle(
                                  color: p.textPrimary,
                                  fontSize: 14.5,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          )
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Center(
                              child: Text(
                                '尚無內容',
                                style: TextStyle(
                                    color: p.textMuted, fontSize: 14),
                              ),
                            ),
                          ),
                  ),
                ],
              ),

              // 6. Floating 4-Icon Bottom Dock: 任務 | 商店 | Nitro | 設定 (matching Screenshot 1!)
              Positioned(
                left: 0,
                right: 0,
                bottom: 18,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1C1D24),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                            color: const Color(0xFF2C2E3A), width: 0.9),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x88000000),
                            blurRadius: 20,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _dockButton(
                            icon: Icons.workspace_premium_outlined,
                            label: '任務',
                            p: p,
                            onTap: () {},
                          ),
                          const SizedBox(width: 24),
                          _dockButton(
                            icon: Icons.storefront_outlined,
                            label: '商店',
                            p: p,
                            onTap: () {},
                          ),
                          const SizedBox(width: 24),
                          _dockButton(
                            icon: Icons.speed_rounded,
                            label: 'Nitro',
                            p: p,
                            onTap: () {},
                          ),
                          const SizedBox(width: 24),
                          _dockButton(
                            icon: Icons.settings_rounded,
                            label: '設定',
                            p: p,
                            onTap: () {
                              Navigator.of(context).pop();
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => DiscordSettingsScreen(
                                      controller: ctrl),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileSubTab(String title, int index, DiscordPalette p) {
    final active = _subTab == index;
    return GestureDetector(
      onTap: () => setState(() => _subTab = index),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF7983F5) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? const Color(0xFF9AA5FF) : p.textMuted,
            fontSize: 14.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _dockButton({
    required IconData icon,
    required String label,
    required DiscordPalette p,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 23),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: p.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
                  title: Text('外觀',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    eco.oledBlackMode ? 'Onyx (純黑省電)' : 'Ash (經典深灰)',
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
                  title: Text('低耗能背景休眠',
                      style: TextStyle(color: p.textPrimary, fontSize: 15)),
                  subtitle: Text(
                    '背景閒置時自動暫停連線以節省電力',
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
              _groupLabel(p, 'Gateway Intents'),
              _settingsGroup(p, [
                SwitchListTile(
                  title: Text('Message Content Intent',
                      style: TextStyle(color: p.textPrimary, fontSize: 14.5)),
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

/// Official Discord Mobile "設定狀態" (Change Status) bottom sheet.
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
                    '變更線上狀態',
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
                            hintText: '今天我學到了...',
                            hintStyle:
                                TextStyle(color: p.textMuted, fontSize: 14),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
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
                      subtitle: Text(acc.username,
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
