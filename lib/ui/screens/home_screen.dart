import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/discord_icons.dart';
import '../widgets/embed_composer_sheet.dart';
import '../widgets/guild_tools_sheet.dart';
import '../widgets/message_tile.dart';
import '../widgets/settings_sheet.dart';

/// 1:1 recreation of the latest 2025/2026 Discord Mobile "You Bar" UI
/// matching the user's uploaded screenshots:
/// - Left Onyx Server Squircles Rail + Top DM Circle
/// - Right Rounded-Top (#14151A) Channel / DM Card with Search + Invite + 頻道與身分組 + INFO ⌄
/// - Bottom Floating Cosmic "You Bar" Capsule (Avatar + Status Ring + Name ⌄ + Status + Bell Badge Pill)
/// - Tap You Bar -> Opens Screenshot 1's Full Modal Profile Sheet (Banner + X + Thought Bubble + 4 Sub-tabs + Bottom 4-Icon Dock)
class HomeScreen extends StatefulWidget {
  final BotClientController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _chatOpenOnPhone = false;
  final _dmSearchCtrl = TextEditingController();
  String _dmFilter = '';

  @override
  void dispose() {
    _dmSearchCtrl.dispose();
    super.dispose();
  }

  static String _statusLabelZh(String st) {
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

  void _openChannelChat(String channelId, {String? guildId}) {
    if (guildId == null) {
      widget.controller.selectDmMode().then((_) {
        widget.controller.selectChannel(channelId);
      });
    } else {
      widget.controller.selectChannel(channelId);
    }
    setState(() => _chatOpenOnPhone = true);
  }

  Future<void> _showNewMessageModal(DiscordPalette p) async {
    final idCtrl = TextEditingController();
    String? errorText;
    bool opening = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: Text('取消',
                            style: TextStyle(color: p.textSecondary)),
                      ),
                      const Expanded(
                        child: Text(
                          '新訊息',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: DiscordPalette.blurple,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: opening
                            ? null
                            : () async {
                                final uid = idCtrl.text.trim();
                                if (!RegExp(r'^[1-9]\d{16,19}$')
                                    .hasMatch(uid)) {
                                  setModalState(() {
                                    errorText = '請輸入有效的 Discord User ID';
                                  });
                                  return;
                                }
                                if (uid ==
                                    widget.controller.activeAccount?.id) {
                                  setModalState(() {
                                    errorText = '無法與自己開啟私訊';
                                  });
                                  return;
                                }
                                setModalState(() {
                                  opening = true;
                                  errorText = null;
                                });
                                try {
                                  await widget.controller.openDmWithUser(uid);
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                  setState(() => _chatOpenOnPhone = true);
                                } catch (e) {
                                  setModalState(() {
                                    opening = false;
                                    errorText = '無法開啟私訊：$e';
                                  });
                                }
                              },
                        child: opening
                            ? const SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('開始對話'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: idCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: TextStyle(color: p.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      prefixText: '收件者：',
                      prefixStyle: TextStyle(color: p.textMuted, fontSize: 15),
                      hintText: '搜尋或輸入 User ID',
                      hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
                      helperText: errorText ?? '輸入單一使用者的 User ID 以開啟私訊。',
                      helperStyle: TextStyle(
                        color: errorText != null
                            ? DiscordPalette.red
                            : p.textMuted,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: p.elevatedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
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

  void _showNotificationsSheet(BotClientController ctrl, DiscordPalette p) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final items = ctrl.notifications;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (_, sCtrl) {
            return Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
                  child: Row(
                    children: [
                      Text(
                        '通知',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: p.border),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.notifications_none_rounded,
                                  size: 46, color: p.textMuted),
                              const SizedBox(height: 10),
                              Text(
                                '目前還沒有任何通知',
                                style: TextStyle(
                                  color: p.textSecondary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: sCtrl,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: p.border),
                          itemBuilder: (_, idx) {
                            final msg = items[idx];
                            final guild = ctrl.findGuildById(msg.guildId);
                            final ch = ctrl.findChannelById(msg.channelId);
                            final whereLabel = guild != null
                                ? '${guild.name}  •  #${ch?.name ?? 'channel'}'
                                : '私人訊息';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: NetworkImage(
                                    msg.author.avatarUrl(size: 64)),
                              ),
                              title: Text(
                                whereLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: p.textMuted, fontSize: 12),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    msg.author.displayName,
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    msg.content.isEmpty
                                        ? '[附件 / Embed]'
                                        : msg.content,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: p.textSecondary, fontSize: 13.5),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                Navigator.of(ctx).pop();
                                if (msg.guildId != null) {
                                  await ctrl.selectGuild(msg.guildId!);
                                }
                                _openChannelChat(msg.channelId,
                                    guildId: msg.guildId);
                              },
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
    final isWide = MediaQuery.of(context).size.width >= 760;

    if (isWide) {
      return Scaffold(
        backgroundColor: p.railBg,
        body: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: 360,
                child: _buildMainYouBarLayout(ctrl, p),
              ),
              VerticalDivider(width: 1, color: p.border),
              Expanded(
                child: _DiscordChatPane(
                  controller: ctrl,
                  palette: p,
                  showBackButton: false,
                  onBack: () {},
                  onOpenDmFromChat: (uid) async {
                    await ctrl.openDmWithUser(uid);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Phone: Full-Screen Chat View (slides back to Rail+Panel+YouBar on back or right-edge swipe)
    if (_chatOpenOnPhone && ctrl.selectedChannel != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
            setState(() => _chatOpenOnPhone = false);
          }
        },
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) > 420) {
              setState(() => _chatOpenOnPhone = false);
            }
          },
          child: Scaffold(
            backgroundColor: p.chatBg,
            body: SafeArea(
              child: _DiscordChatPane(
                controller: ctrl,
                palette: p,
                showBackButton: true,
                onBack: () => setState(() => _chatOpenOnPhone = false),
                onOpenDmFromChat: (uid) async {
                  await ctrl.openDmWithUser(uid);
                  setState(() => _chatOpenOnPhone = true);
                },
              ),
            ),
          ),
        ),
      );
    }

    // Main Home Screen matching Screenshot 2 (Rail + Rounded Panel + Floating You Bar)
    return Scaffold(
      backgroundColor: p.railBg,
      body: SafeArea(
        bottom: false,
        child: _buildMainYouBarLayout(ctrl, p),
      ),
    );
  }

  Widget _buildMainYouBarLayout(BotClientController ctrl, DiscordPalette p) {
    final isDmMode = ctrl.selectedGuildId == null;
    final guilds = ctrl.guilds;
    final selectedGuild = ctrl.selectedGuild;
    final iconPx = ctrl.ecoSettings.avatarSize;

    return Stack(
      children: [
        // 1. Left Server Rail + Right Rounded Sheet
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Vertical Rail (68px) — Squircles for Servers, Circle for top DM!
              SizedBox(
                width: 68,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(0, 6, 0, 96),
                  children: [
                    // Top Direct Messages Circle Button
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: GestureDetector(
                        onTap: () => ctrl.selectDmMode(),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              width: 4,
                              height: isDmMode ? 32 : 0,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.horizontal(
                                    right: Radius.circular(4)),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isDmMode
                                    ? DiscordPalette.blurple
                                    : const Color(0xFF1D1E25),
                                borderRadius:
                                    BorderRadius.circular(isDmMode ? 14 : 23),
                              ),
                              child: const Icon(
                                Icons.chat_bubble_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 4),
                          ],
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 6),
                      child: Divider(height: 1, color: p.border),
                    ),

                    // Server Squircles (matching Screenshot 2!)
                    ...guilds.map((g) {
                      final selected =
                          !isDmMode && ctrl.selectedGuildId == g.id;
                      final hasUnread = g.channels
                          .any((c) => ctrl.unreadChannelIds.contains(c.id));
                      final iconUrl = g.iconUrl(size: iconPx);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.5),
                        child: GestureDetector(
                          onTap: () => ctrl.selectGuild(g.id),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 4,
                                height: selected
                                    ? 34
                                    : (hasUnread ? 8 : 0),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.horizontal(
                                      right: Radius.circular(4)),
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 46,
                                height: 46,
                                clipBehavior: Clip.antiAlias,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? DiscordPalette.blurple
                                      : const Color(0xFF1E1F26),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: iconUrl != null
                                    ? Image.network(
                                        iconUrl,
                                        width: 46,
                                        height: 46,
                                        cacheWidth: iconPx,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Text(
                                          g.initials,
                                          style: const TextStyle(
                                            color: Color(0xFFD5D7DD),
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                          ),
                                        ),
                                      )
                                    : Text(
                                        g.initials,
                                        style: const TextStyle(
                                          color: Color(0xFFD5D7DD),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13.5,
                                        ),
                                      ),
                              ),
                              const Spacer(),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Right Rounded Card (#14151A, topLeft & topRight 24px matching Screenshot 2)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: p.sidebarBg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: p.border, width: 0.9),
                        left: BorderSide(color: p.border, width: 0.9),
                        right: BorderSide(color: p.border, width: 0.5),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: isDmMode
                        ? _buildDmPanel(ctrl, p)
                        : _buildGuildPanel(ctrl, p, selectedGuild),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Bottom Floating Cosmic "You Bar" Capsule (1:1 Screenshot 2!)
        Positioned(
          left: 10,
          right: 10,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          child: _buildFloatingYouBar(ctrl, p),
        ),
      ],
    );
  }

  /// Exact Floating "You Bar" at the bottom of Screenshot 2!
  Widget _buildFloatingYouBar(BotClientController ctrl, DiscordPalette p) {
    final acc = ctrl.activeAccount;
    if (acc == null) return const SizedBox.shrink();

    final badgeCount =
        ctrl.notifications.length + ctrl.unreadChannelIds.length;
    final bannerUrl = acc.bannerUrl(size: 480);

    return GestureDetector(
      onTap: () => showYouProfileModal(context, ctrl),
      onLongPress: () => showSwitchAccountsSheet(context, ctrl),
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: const Color(0xFF2D3142), width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0xAA000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF181A24),
              Color(0xFF172236),
              Color(0xFF12355B),
            ],
          ),
          image: bannerUrl != null
              ? DecorationImage(
                  image: NetworkImage(bannerUrl),
                  fit: BoxFit.cover,
                  colorFilter: const ColorFilter.mode(
                    Color(0xAA10131C),
                    BlendMode.darken,
                  ),
                )
              : null,
        ),
        padding: const EdgeInsets.fromLTRB(7, 6, 10, 6),
        child: Row(
          children: [
            // Left Circular Avatar + Exact Discord Status Ring
            Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 23,
                  backgroundImage: NetworkImage(acc.avatarUrl(size: 96)),
                ),
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: DiscordStatusBadge(
                    status: ctrl.botStatus,
                    size: 16,
                    borderColor: const Color(0xFF181A24),
                    borderWidth: 2.8,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),

            // Middle: Display Name + Tag Pill + Chevron + Status Text
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          acc.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5.5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xBB1E2130),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                              color: const Color(0xFF34384E), width: 0.6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.bolt_rounded,
                                size: 11, color: Color(0xFFB784F7)),
                            SizedBox(width: 2),
                            Text(
                              'BOT',
                              style: TextStyle(
                                color: Color(0xFFE3E5E8),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: Color(0xFFD5D7DD),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    ctrl.botActivityName.isNotEmpty
                        ? ctrl.botActivityName
                        : _statusLabelZh(ctrl.botStatus),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFB5BAC1),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Right Bell + Red Badge Pill (matching Screenshot 2!)
            GestureDetector(
              onTap: () => _showNotificationsSheet(ctrl, p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xCC0E1017),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: const Color(0xFF282C3C), width: 0.7),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.notifications_rounded,
                      color: Colors.white,
                      size: 19,
                    ),
                    if (badgeCount > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5.5, vertical: 1),
                        decoration: BoxDecoration(
                          color: DiscordPalette.danger,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatMemberCount(int count) {
    final s = count.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  void _showChannelQuickSearch(DiscordGuild guild, DiscordPalette p) {
    final qCtrl = TextEditingController();
    String q = '';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final filtered = guild.channels
              .where((c) =>
                  c.isMessageable &&
                  widget.controller.canViewChannel(guild, c) &&
                  c.name.toLowerCase().contains(q.toLowerCase()))
              .toList();
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            builder: (_, sCtrl) => Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: qCtrl,
                    autofocus: true,
                    onChanged: (v) => setM(() => q = v),
                    style: TextStyle(color: p.textPrimary),
                    decoration: InputDecoration(
                      hintText: '搜尋頻道...',
                      prefixIcon: Icon(Icons.search_rounded, color: p.textMuted),
                      filled: true,
                      fillColor: p.elevatedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      controller: sCtrl,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final ch = filtered[i];
                        return ListTile(
                          leading: Icon(Icons.tag_rounded, color: p.textMuted),
                          title: Text(ch.name,
                              style: TextStyle(color: p.textPrimary)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            _openChannelChat(ch.id, guildId: guild.id);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateChannelModal(
    DiscordGuild guild,
    DiscordPalette p,
  ) async {
    final nameCtrl = TextEditingController();
    int type = 0;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: p.cardBg,
          title: const Text('建立頻道'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: type,
                dropdownColor: p.cardBg,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('文字頻道')),
                  DropdownMenuItem(value: 2, child: Text('語音頻道')),
                ],
                onChanged: (v) {
                  if (v != null) setDlg(() => type = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: '新頻道名稱'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  final created = await widget.controller.rest!
                      .createGuildChannel(guild.id, name: name, type: type);
                  _openChannelChat(created.id, guildId: guild.id);
                } catch (_) {}
              },
              child: const Text('建立'),
            ),
          ],
        ),
      ),
    );
  }

  /// Right Rounded Guild Channel Sheet (1:1 Screenshot 2!)
  Widget _buildGuildPanel(
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild? guild,
  ) {
    if (guild == null) {
      return Center(
        child: Text('尚未加入任何伺服器', style: TextStyle(color: p.textMuted)),
      );
    }

    final allChannels = guild.channels;
    final categories = allChannels.where((c) => c.isCategory).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final uncategorized = allChannels
        .where((c) =>
            !c.isCategory &&
            c.parentId == null &&
            c.isMessageable &&
            ctrl.canViewChannel(guild, c))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final channelWidgets = <Widget>[];
    for (final ch in uncategorized) {
      channelWidgets.add(_buildScreenshotChannelRow(ctrl, p, guild, ch));
    }

    for (final cat in categories) {
      final children = allChannels
          .where((c) =>
              !c.isCategory &&
              c.parentId == cat.id &&
              c.isMessageable &&
              ctrl.canViewChannel(guild, c))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      if (children.isEmpty) continue;

      final collapsed = ctrl.isCategoryCollapsed(cat.id);
      // Category Header: "INFO ⌄" with chevron AFTER text (matching Screenshot 2!)
      channelWidgets.add(
        InkWell(
          onTap: () => ctrl.toggleCategoryCollapse(cat.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 6),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    cat.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  collapsed
                      ? Icons.keyboard_arrow_right_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: p.textMuted,
                ),
              ],
            ),
          ),
        ),
      );

      if (!collapsed) {
        for (final ch in children) {
          channelWidgets.add(_buildScreenshotChannelRow(ctrl, p, guild, ch));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 92),
      children: [
        // 1. Server Title + Badge + Chevron + Member Count + Search + Invite (1:1 Screenshot 2)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showCreateChannelModal(guild, p),
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        guild.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.verified_rounded,
                      size: 17,
                      color: Color(0xFFD888F8),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: p.textMuted,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 3),
              Text(
                guild.memberCount != null
                    ? '${_formatMemberCount(guild.memberCount!)} 位成員 • 社群'
                    : '${guild.channels.length} 個頻道 • 社群',
                style: TextStyle(
                  color: p.textMuted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),

              // Search Bar Button + Square Person-Add Invite Button
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showChannelQuickSearch(guild, p),
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: p.elevatedBg,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_rounded,
                                size: 18, color: p.textSecondary),
                            const SizedBox(width: 6),
                            Text(
                              '搜尋',
                              style: TextStyle(
                                color: p.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final ch = ctrl.selectedChannel ??
                          (uncategorized.isNotEmpty
                              ? uncategorized.first
                              : null);
                      if (ch == null || ctrl.rest == null) return;
                      try {
                        final url =
                            await ctrl.rest!.createChannelInvite(ch.id);
                        await Clipboard.setData(ClipboardData(text: url));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('已複製邀請連結：$url')),
                          );
                        }
                      } catch (_) {}
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: p.elevatedBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 18,
                        color: Color(0xFFE3E5E8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        Divider(height: 1, color: p.border),

        // 2. "頻道與身分組" + "新的" pill row (matching Screenshot 2!)
        InkWell(
          onTap: () => _showChannelQuickSearch(guild, p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Icon(Icons.manage_search_rounded,
                    size: 21, color: p.textMuted),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '頻道與身分組',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2442),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '新的',
                    style: TextStyle(
                      color: Color(0xFF9AA9F7),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Divider(height: 1, color: p.border),
        const SizedBox(height: 6),

        // 3. Channel Rows
        ...channelWidgets,
      ],
    );
  }

  Widget _buildScreenshotChannelRow(
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel ch,
  ) {
    final selected = ctrl.selectedChannelId == ch.id;
    final unread = ctrl.unreadChannelIds.contains(ch.id);
    final lower = ch.name.toLowerCase();
    final isRules = lower.contains('rule') || lower.contains('規則');
    final isLocked = ch.permissionOverwrites.any(
      (ow) =>
          ow.id == guild.id &&
          DiscordPermissions.has(ow.deny, DiscordPermissions.viewChannel),
    );

    final iconColor = (selected || unread) ? Colors.white : p.textMuted;

    Widget leadingIcon;
    if (isRules) {
      leadingIcon =
          Icon(Icons.fact_check_outlined, size: 20, color: iconColor);
    } else if (ch.type == 5) {
      leadingIcon = Icon(Icons.campaign_rounded, size: 21, color: iconColor);
    } else if (ch.type == 2) {
      leadingIcon = Icon(Icons.volume_up_rounded, size: 20, color: iconColor);
    } else {
      leadingIcon = DiscordChannelHashIcon(
        locked: isLocked,
        color: iconColor,
        size: 21,
      );
    }

    return Stack(
      alignment: Alignment.centerLeft,
      children: [
        // Left-edge white semicircle dot (matching Screenshot 2!)
        if (unread || selected)
          Container(
            width: 4,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.horizontal(right: Radius.circular(4)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _openChannelChat(ch.id, guildId: guild.id),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10.5),
              decoration: BoxDecoration(
                color: selected ? p.selectedChannelBg : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  leadingIcon,
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      ch.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: (selected || unread)
                            ? Colors.white
                            : p.textSecondary,
                        fontSize: 15.5,
                        fontWeight: (selected || unread)
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Right Rounded DM Panel (when top DM circle is active)
  Widget _buildDmPanel(BotClientController ctrl, DiscordPalette p) {
    final allDms = ctrl.dmChannels;
    final dms = _dmFilter.isEmpty
        ? allDms
        : allDms
            .where((c) =>
                c.displayTitle.toLowerCase().contains(_dmFilter.toLowerCase()))
            .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 10),
          child: Row(
            children: [
              Text(
                '訊息',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showNewMessageModal(p),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: p.elevatedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded,
                          size: 16, color: p.textPrimary),
                      const SizedBox(width: 6),
                      Text(
                        '新訊息',
                        style: TextStyle(
                          color: p.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: TextField(
            controller: _dmSearchCtrl,
            onChanged: (v) => setState(() => _dmFilter = v),
            style: TextStyle(color: p.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: '搜尋',
              hintStyle: TextStyle(color: p.textMuted, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search_rounded, color: p.textMuted, size: 19),
              filled: true,
              fillColor: p.elevatedBg,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: dms.isEmpty
              ? Center(
                  child: Text(
                    '尚無私人訊息',
                    style: TextStyle(color: p.textMuted, fontSize: 14),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 92),
                  itemCount: dms.length,
                  itemBuilder: (_, idx) {
                    final ch = dms[idx];
                    final user = ch.dmRecipient;
                    final unread = ctrl.unreadChannelIds.contains(ch.id);

                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: CircleAvatar(
                        radius: 21,
                        backgroundImage: user != null
                            ? NetworkImage(user.avatarUrl(size: 96))
                            : null,
                        child:
                            user == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(
                        ch.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: unread ? Colors.white : p.textSecondary,
                          fontWeight:
                              unread ? FontWeight.w700 : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        user != null ? user.username : '私人訊息',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textMuted, fontSize: 12.5),
                      ),
                      onTap: () => _openChannelChat(ch.id, guildId: null),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Full-Screen 1:1 Discord Mobile Chat View
class _DiscordChatPane extends StatefulWidget {
  final BotClientController controller;
  final DiscordPalette palette;
  final bool showBackButton;
  final VoidCallback onBack;
  final Future<void> Function(String userId) onOpenDmFromChat;

  const _DiscordChatPane({
    required this.controller,
    required this.palette,
    required this.showBackButton,
    required this.onBack,
    required this.onOpenDmFromChat,
  });

  @override
  State<_DiscordChatPane> createState() => _DiscordChatPaneState();
}

class _DiscordChatPaneState extends State<_DiscordChatPane> {
  final _composerCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _imagePicker = ImagePicker();

  DiscordMessage? _replyTarget;
  DiscordMessage? _editingTarget;
  Uint8List? _pendingAttachmentBytes;
  String? _pendingAttachmentName;
  bool _sending = false;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _composerCtrl.addListener(() {
      final nonEmpty = _composerCtrl.text.trim().isNotEmpty;
      if (nonEmpty != _hasText) {
        setState(() => _hasText = nonEmpty);
      }
    });
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    _composerCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      widget.controller.loadOlderMessages();
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: widget.controller.ecoSettings.ecoPowerSaving ? 82 : 95,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      setState(() {
        _pendingAttachmentBytes = bytes;
        _pendingAttachmentName = picked.name;
      });
    } catch (_) {}
  }

  Future<void> _send({
    List<DiscordEmbed>? embeds,
    String? overrideContent,
  }) async {
    final text = (overrideContent ?? _composerCtrl.text).trim();

    if (_editingTarget != null) {
      if (text.isEmpty) return;
      final target = _editingTarget!;
      setState(() {
        _editingTarget = null;
        _composerCtrl.clear();
      });
      try {
        await widget.controller.editChatMessage(target.id, text);
      } catch (_) {}
      return;
    }

    if (text.isEmpty &&
        (embeds == null || embeds.isEmpty) &&
        _pendingAttachmentBytes == null) {
      return;
    }

    final replyId = _replyTarget?.id;
    final fileBytes = _pendingAttachmentBytes;
    final fileName = _pendingAttachmentName;

    setState(() {
      _sending = true;
      if (overrideContent == null) _composerCtrl.clear();
      _replyTarget = null;
      _pendingAttachmentBytes = null;
      _pendingAttachmentName = null;
    });

    try {
      await widget.controller.sendChatMessage(
        content: text,
        replyToMessageId: replyId,
        embeds: embeds,
        fileBytes: fileBytes,
        fileName: fileName,
      );
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openPinsSheet() {
    final ch = widget.controller.selectedChannel;
    final rest = widget.controller.rest;
    final p = widget.palette;
    if (ch == null || rest == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, sCtrl) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  '釘選訊息',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Divider(height: 1, color: p.border),
              Expanded(
                child: FutureBuilder<List<DiscordMessage>>(
                  future: rest.getPinnedMessages(ch.id),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final pins = snap.data ?? const [];
                    if (pins.isEmpty) {
                      return Center(
                        child: Text(
                          '此頻道目前沒有任何釘選訊息',
                          style: TextStyle(color: p.textMuted, fontSize: 13.5),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: sCtrl,
                      padding: const EdgeInsets.all(14),
                      itemCount: pins.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: p.border, height: 18),
                      itemBuilder: (_, i) {
                        final m = pins[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundImage:
                                NetworkImage(m.author.avatarUrl(size: 64)),
                          ),
                          title: Text(
                            m.author.displayName,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            m.content.isEmpty ? '[Embed / 附件]' : m.content,
                            style: TextStyle(color: p.textSecondary),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openMembersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChannelMembersSheet(
        controller: widget.controller,
        palette: widget.palette,
        onOpenPins: _openPinsSheet,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final p = widget.palette;
    final channel = ctrl.selectedChannel;
    final guild = ctrl.selectedGuild;
    final perms = ctrl.currentChannelPermissions();
    final canManageMessages =
        DiscordPermissions.has(perms, DiscordPermissions.manageMessages);
    final canEmbed =
        DiscordPermissions.has(perms, DiscordPermissions.embedLinks);
    final canSend = ctrl.canSendInSelectedChannel();

    if (channel == null) {
      return Center(
        child: Text(
          '選擇一個頻道開始對話',
          style: TextStyle(color: p.textMuted, fontSize: 15),
        ),
      );
    }

    final dmUser = channel.dmRecipient;

    return Column(
      children: [
        // Top Chat Header
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: p.chatBg,
            border: Border(bottom: BorderSide(color: p.border, width: 0.6)),
          ),
          child: Row(
            children: [
              if (widget.showBackButton)
                IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: p.textPrimary),
                  onPressed: widget.onBack,
                )
              else
                const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _openMembersSheet,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        if (channel.isDm && dmUser != null)
                          CircleAvatar(
                            radius: 13,
                            backgroundImage:
                                NetworkImage(dmUser.avatarUrl(size: 64)),
                          )
                        else
                          Icon(
                            channel.isVoice
                                ? Icons.volume_up_rounded
                                : Icons.tag_rounded,
                            size: 21,
                            color: p.textMuted,
                          ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            channel.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: p.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.group_rounded,
                    color: p.textSecondary, size: 22),
                onPressed: _openMembersSheet,
              ),
            ],
          ),
        ),

        // 120fps Virtualized Chat Feed
        Expanded(
          child: ValueListenableBuilder<bool>(
            valueListenable: ctrl.loadingMessagesNotifier,
            builder: (_, loading, __) {
              if (loading) {
                return const Center(child: CircularProgressIndicator());
              }
              return ValueListenableBuilder<List<DiscordMessage>>(
                valueListenable: ctrl.messagesNotifier,
                builder: (_, messages, __) {
                  if (messages.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: ctrl.refreshCurrentChannel,
                      child: ListView(
                        reverse: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: p.inputBg,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    channel.isDm
                                        ? Icons.alternate_email_rounded
                                        : Icons.tag_rounded,
                                    size: 34,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  channel.isDm
                                      ? channel.displayTitle
                                      : '歡迎來到 #${channel.name}！',
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  channel.isDm
                                      ? '這是您與 ${channel.displayTitle} 私人訊息紀錄的開頭。'
                                      : '這是 #${channel.name} 頻道的起點。',
                                  style: TextStyle(
                                    color: p.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      bool compact = false;
                      if (index + 1 < messages.length) {
                        final older = messages[index + 1];
                        if (older.author.id == msg.author.id &&
                            msg.referencedMessage == null &&
                            msg.timestamp
                                    .difference(older.timestamp)
                                    .inMinutes
                                    .abs() <
                                5) {
                          compact = true;
                        }
                      }

                      return MessageTile(
                        key: ValueKey(msg.id),
                        message: msg,
                        compact: compact,
                        palette: p,
                        guild: guild,
                        currentBotUserId: ctrl.activeAccount?.id ?? '',
                        ecoMode: ctrl.ecoSettings.ecoPowerSaving,
                        canManageMessages: canManageMessages,
                        onReply: (m) => setState(() {
                          _editingTarget = null;
                          _replyTarget = m;
                        }),
                        onEdit: (m) => setState(() {
                          _replyTarget = null;
                          _editingTarget = m;
                          _composerCtrl.text = m.content;
                        }),
                        onDelete: (m) async {
                          try {
                            await ctrl.deleteChatMessage(m.id);
                          } catch (_) {}
                        },
                        onTogglePin: (m) async {
                          try {
                            if (m.pinned) {
                              await ctrl.rest
                                  ?.unpinMessage(m.channelId, m.id);
                            } else {
                              await ctrl.rest?.pinMessage(m.channelId, m.id);
                            }
                            await ctrl.refreshCurrentChannel();
                          } catch (_) {}
                        },
                        onToggleReaction: (m, emoji, me) async {
                          try {
                            await ctrl.toggleReaction(m, emoji, me);
                          } catch (_) {}
                        },
                        onOpenDm: widget.onOpenDmFromChat,
                      );
                    },
                  );
                },
              );
            },
          ),
        ),

        // Typing Indicator
        ValueListenableBuilder<String?>(
          valueListenable: ctrl.typingBannerNotifier,
          builder: (_, text, __) {
            if (text == null) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              color: p.chatBg,
              child: Text(
                text,
                style: TextStyle(color: p.textSecondary, fontSize: 11.5),
              ),
            );
          },
        ),

        // Replying / Editing / Attachment Bar
        if (_replyTarget != null ||
            _editingTarget != null ||
            _pendingAttachmentName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: p.sidebarBg,
              border: Border(top: BorderSide(color: p.border, width: 0.6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _editingTarget != null
                        ? '正在編輯訊息'
                        : (_pendingAttachmentName != null
                            ? '已附加檔案：$_pendingAttachmentName'
                            : '回覆 ${_replyTarget!.author.displayName}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    _replyTarget = null;
                    _editingTarget = null;
                    _pendingAttachmentBytes = null;
                    _pendingAttachmentName = null;
                  }),
                  child: Icon(Icons.cancel_rounded,
                      size: 18, color: p.textMuted),
                ),
              ],
            ),
          ),

        // Bottom Chat Composer Bar
        Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
          decoration: BoxDecoration(
            color: p.chatBg,
            border: Border(top: BorderSide(color: p.border, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: canSend ? _pickAttachment : null,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: p.inputBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded,
                      color: p.textSecondary, size: 23),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: p.inputBg,
                    borderRadius: BorderRadius.circular(21),
                  ),
                  padding: const EdgeInsets.only(left: 14, right: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _composerCtrl,
                          enabled: canSend,
                          minLines: 1,
                          maxLines: 5,
                          onChanged: (_) => ctrl.notifyUserTyping(),
                          style:
                              TextStyle(color: p.textPrimary, fontSize: 15),
                          decoration: InputDecoration(
                            hintText: canSend
                                ? (channel.isDm
                                    ? '傳送訊息給 @${channel.displayTitle}'
                                    : '傳送訊息至 #${channel.name}')
                                : '您沒有在此頻道發送訊息的權限',
                            hintStyle:
                                TextStyle(color: p.textMuted, fontSize: 14.5),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      if (canSend && canEmbed)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Create Embed',
                          onPressed: () {
                            showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => EmbedComposerSheet(
                                palette: p,
                                onSend: (emb, extra) => _send(
                                  embeds: [emb],
                                  overrideContent: extra,
                                ),
                              ),
                            );
                          },
                          icon: DbcEmbedIcon(
                            size: 19,
                            color: p.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (_hasText || _pendingAttachmentBytes != null || _sending) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: (!canSend || _sending) ? null : () => _send(),
                  child: Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: DiscordPalette.blurple,
                      shape: BoxShape.circle,
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 17,
                            height: 17,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons.send_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
