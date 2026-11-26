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
import '../widgets/user_profile_sheet.dart';
import '../widgets/voice_channel_sheet.dart';

/// Authentic 2025/2026 Discord Mobile 3-Panel Gesture Architecture:
/// - Panel -1.0 (Left): Server Rail + Channel/DM List + Clean Solid Floating You Bar
/// - Panel  0.0 (Center): Active Channel / DM / Forum Chat View
/// - Panel +1.0 (Right): Channel Details & Categorized Role Member List Drawer
/// All transitions support interactive 120fps finger-tracking horizontal drag & velocity fling!
class HomeScreen extends StatefulWidget {
  final BotClientController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _panelCtrl;
  final _dmSearchCtrl = TextEditingController();
  String _dmFilter = '';

  @override
  void initState() {
    super.initState();
    // -1.0 = Left Drawer (Rail + Channels + You Bar), 0.0 = Center Chat, +1.0 = Right Member Drawer
    _panelCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      lowerBound: -1.0,
      upperBound: 1.0,
      value: -1.0,
    );
    widget.controller.setActivelyViewingChat(false);
  }

  @override
  void dispose() {
    _panelCtrl.dispose();
    _dmSearchCtrl.dispose();
    super.dispose();
  }

  void _animateToPanel(double target) {
    final clamped = target.clamp(-1.0, 1.0);
    widget.controller.setActivelyViewingChat(clamped == 0.0);
    _panelCtrl.animateTo(
      clamped,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
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
        widget.controller.selectChannel(channelId, markRead: true);
      });
    } else {
      widget.controller.selectChannel(channelId, markRead: true);
    }
    _animateToPanel(0.0);
  }

  void _openVoiceSheet(DiscordGuild guild, DiscordChannel channel) {
    showVoiceChannelSheet(
      context,
      controller: widget.controller,
      guild: guild,
      channel: channel,
      onOpenVoiceTextChat: (chId, gId) {
        _openChannelChat(chId, guildId: gId);
      },
      onNavigateToDm: () => _animateToPanel(0.0),
    );
  }

  Widget _buildActiveVoiceStatusBar(
    BotClientController ctrl,
    DiscordPalette p,
  ) {
    final voiceCh = ctrl.activeVoiceChannel;
    final voiceGuild = ctrl.findGuildById(ctrl.activeVoiceGuildId);
    if (voiceCh == null || voiceGuild == null) {
      return const SizedBox.shrink();
    }

    return Material(
      color: const Color(0xFF16291F),
      child: InkWell(
        onTap: () => _openVoiceSheet(voiceGuild, voiceCh),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFF234433), width: 0.8),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.volume_up_rounded,
                size: 17,
                color: DiscordPalette.green,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: ValueListenableBuilder<int?>(
                  valueListenable: ctrl.voicePingMsNotifier,
                  builder: (_, pingMs, __) {
                    final effectivePing = pingMs ?? ctrl.pingMsNotifier.value;
                    final pingPart =
                        effectivePing != null ? ' ($effectivePing ms)' : '';
                    return Text(
                      '${voiceCh.name} • ${voiceGuild.name}$pingPart',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFE3FCEF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  ctrl.toggleVoiceMute();
                },
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Icon(
                    ctrl.selfMute ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 18,
                    color: ctrl.selfMute
                        ? DiscordPalette.red
                        : const Color(0xFFE3FCEF),
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  ctrl.leaveVoiceChannel();
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 6, right: 2, top: 6, bottom: 6),
                  child: Icon(
                    Icons.call_end_rounded,
                    size: 19,
                    color: DiscordPalette.red,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
                                    errorText =
                                        'Select a user or enter a valid Discord User ID.';
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
                                  _animateToPanel(0.0);
                                } catch (e) {
                                  setModalState(() {
                                    opening = false;
                                    errorText = '$e';
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
    ctrl.markNotificationsRead();
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
                                '目前沒有任何提及或私訊通知',
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
                                    msg.authorDisplayName(guild),
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

  void _openPinsModal(DiscordPalette p) {
    final ch = widget.controller.selectedChannel;
    final rest = widget.controller.rest;
    if (ch == null || rest == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        builder: (_, sCtrl) => Column(
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
                        onTap: () => showUserProfileSheet(
                          context,
                          controller: widget.controller,
                          initialUser: m.author,
                          guildId: widget.controller.selectedGuildId,
                          onNavigateToDm: () {
                            Navigator.of(context).pop();
                            _animateToPanel(0.0);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 840;

    if (isWide) {
      // Desktop / Tablet 3-column layout
      if (!ctrl.isActivelyViewingChat) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ctrl.setActivelyViewingChat(true);
        });
      }
      return Scaffold(
        backgroundColor: p.railBg,
        body: SafeArea(
          child: Column(
            children: [
              if (ctrl.activeVoiceChannel != null)
                _buildActiveVoiceStatusBar(ctrl, p),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(
                      width: 340,
                      child: _buildLeftNavigationPanel(ctrl, p),
                    ),
                    VerticalDivider(width: 1, color: p.border),
                    Expanded(
                      child: _DiscordChatPane(
                        controller: ctrl,
                        palette: p,
                        showBackButton: false,
                        onBack: () {},
                        onToggleRightDrawer: () {},
                        onEnsureCenterChat: () {},
                        onOpenVoiceRoom: (g, ch) => _openVoiceSheet(g, ch),
                        onSelectForumPost: (threadId) =>
                            ctrl.selectChannel(threadId, markRead: true),
                        onOpenDmFromChat: (uid) async {
                          await ctrl.openDmWithUser(uid);
                        },
                      ),
                    ),
                    VerticalDivider(width: 1, color: p.border),
                    SizedBox(
                      width: 280,
                      child: ChannelDetailsSidePanel(
                        controller: ctrl,
                        palette: p,
                        onOpenPins: () => _openPinsModal(p),
                        onSelectThread: (tid) =>
                            ctrl.selectChannel(tid, markRead: true),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Phone: Authentic 3-Panel Interactive Horizontal Gesture Canvas!
    return AnimatedBuilder(
      animation: _panelCtrl,
      builder: (context, _) {
        final v = _panelCtrl.value; // -1.0 (Left) .. 0.0 (Chat) .. +1.0 (Right)
        final canPopApp = v <= -0.95;

        return PopScope(
          canPop: canPopApp,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            if (v > 0.2) {
              _animateToPanel(0.0);
            } else {
              _animateToPanel(-1.0);
            }
          },
          child: Scaffold(
            backgroundColor: p.railBg,
            body: SafeArea(
              bottom: v > -0.5,
              child: Column(
                children: [
                  if (ctrl.activeVoiceChannel != null)
                    _buildActiveVoiceStatusBar(ctrl, p),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final rightDrawerW = w * 0.84;

                  // Parallax & translation math
                  final leftPanelOffset =
                      v < 0 ? (-v - 1.0) * w * 0.28 : -w * 0.28;
                  final chatOffset = v < 0
                      ? (-v) * w
                      : -v * rightDrawerW;
                  final rightOffset = w - (v > 0 ? v * rightDrawerW : 0);

                  return GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: (details) {
                      final dx = details.delta.dx;
                      // Avoid stealing left-drag inside center chat unless starting near right edge (so Swipe-to-Reply works seamlessly!)
                      if (_panelCtrl.value.abs() < 0.05 &&
                          dx < 0 &&
                          details.globalPosition.dx < w - 44) {
                        return;
                      }
                      if (ctrl.selectedChannel == null &&
                          _panelCtrl.value <= -0.95 &&
                          dx < 0) {
                        return;
                      }
                      final deltaVal = -dx / w;
                      _panelCtrl.value =
                          (_panelCtrl.value + deltaVal).clamp(-1.0, 1.0);
                    },
                    onHorizontalDragEnd: (details) {
                      final vx = details.primaryVelocity ?? 0;
                      final cur = _panelCtrl.value;
                      if (vx < -480) {
                        // Fast swipe left
                        if (cur < -0.15 && ctrl.selectedChannel != null) {
                          _animateToPanel(0.0);
                        } else if (cur >= -0.15) {
                          _animateToPanel(1.0);
                        } else {
                          _animateToPanel(-1.0);
                        }
                      } else if (vx > 480) {
                        // Fast swipe right
                        if (cur > 0.15) {
                          _animateToPanel(0.0);
                        } else {
                          _animateToPanel(-1.0);
                        }
                      } else {
                        // Snap to nearest panel
                        if (cur < -0.45) {
                          _animateToPanel(-1.0);
                        } else if (cur > 0.42) {
                          _animateToPanel(1.0);
                        } else {
                          _animateToPanel(0.0);
                        }
                      }
                    },
                    child: Stack(
                      children: [
                        // 1. Left Panel (Server Rail + Channel/DM Sheet + Clean You Bar)
                        if (v < -0.001)
                          Transform.translate(
                            offset: Offset(leftPanelOffset, 0),
                            child: IgnorePointer(
                              ignoring: v > -0.5,
                              child: _buildLeftNavigationPanel(ctrl, p),
                            ),
                          ),

                        // 2. Center Chat Panel (slides smoothly over Left Panel)
                        if (v > -0.999)
                          Transform.translate(
                            offset: Offset(chatOffset, 0),
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x88000000),
                                    blurRadius: 20,
                                    offset: Offset(-4, 0),
                                  ),
                                ],
                              ),
                              child: Stack(
                                children: [
                                  IgnorePointer(
                                    ignoring: v < -0.2 || v > 0.2,
                                    child: Container(
                                      color: p.chatBg,
                                      child: _DiscordChatPane(
                                        controller: ctrl,
                                        palette: p,
                                        showBackButton: true,
                                        onBack: () => _animateToPanel(-1.0),
                                        onToggleRightDrawer: () =>
                                            _animateToPanel(1.0),
                                        onEnsureCenterChat: () =>
                                            _animateToPanel(0.0),
                                        onOpenVoiceRoom: (g, ch) =>
                                            _openVoiceSheet(g, ch),
                                        onSelectForumPost: (tid) =>
                                            _openChannelChat(
                                          tid,
                                          guildId: ctrl.selectedGuildId,
                                        ),
                                        onOpenDmFromChat: (uid) async {
                                          try {
                                            await ctrl.openDmWithUser(uid);
                                            _animateToPanel(0.0);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(content: Text('$e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                  ),
                                  // Tap-to-dismiss scrim when Left or Right drawer is open
                                  if (v < -0.05 || v > 0.05)
                                    Positioned.fill(
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _animateToPanel(
                                            v < -0.5 ? -1.0 : 0.0),
                                        child: ColoredBox(
                                          color: Colors.black.withAlpha(
                                            ((v.abs()) * 120).round().clamp(0, 140),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                        // 3. Right Panel (Channel Info & Categorized Role Member List)
                        if (v > 0.001)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: rightOffset,
                            width: rightDrawerW,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border(
                                    left: BorderSide(
                                        color: p.border, width: 0.8)),
                              ),
                              child: ChannelDetailsSidePanel(
                                controller: ctrl,
                                palette: p,
                                onOpenPins: () => _openPinsModal(p),
                                onSelectThread: (tid) {
                                  ctrl.selectChannel(tid, markRead: true);
                                  _animateToPanel(0.0);
                                },
                                onClosePanel: () => _animateToPanel(0.0),
                                onNavigateToDm: () => _animateToPanel(0.0),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
},
);
}

  Widget _buildLeftNavigationPanel(
    BotClientController ctrl,
    DiscordPalette p,
  ) {
    final isDmMode = ctrl.selectedGuildId == null;
    final guilds = ctrl.guilds;
    final selectedGuild = ctrl.selectedGuild;
    final iconPx = ctrl.ecoSettings.avatarSize;
    final hasUnreadDms =
        ctrl.dmChannels.any((c) => ctrl.unreadChannelIds.contains(c.id));

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Vertical Server Rail (68px)
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
                              height: isDmMode
                                  ? 32
                                  : (hasUnreadDms ? 8 : 0),
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

                    // Server Squircles
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

              // Right Rounded Channel / DM Card
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

        // Bottom Clean Solid Floating "You Bar" (NO fake user nameplate cosmetics!)
        Positioned(
          left: 10,
          right: 10,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          child: _buildCleanFloatingYouBar(ctrl, p),
        ),
      ],
    );
  }

  /// Clean, non-decorated Discord Mobile "You Bar":
  /// - Tap: opens Profile Modal
  /// - Long-press: opens Switch Accounts
  /// - Horizontal swipe across You Bar: flips between DMs and active Server!
  Widget _buildCleanFloatingYouBar(
    BotClientController ctrl,
    DiscordPalette p,
  ) {
    final acc = ctrl.activeAccount;
    if (acc == null) return const SizedBox.shrink();

    final badgeCount = ctrl.unreadNotificationCount;

    return GestureDetector(
      onTap: () => showYouProfileModal(context, ctrl),
      onLongPress: () => showSwitchAccountsSheet(context, ctrl),
      onHorizontalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0).abs() > 260) {
          HapticFeedback.selectionClick();
          ctrl.flipDmAndServer();
        }
      },
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          color: p.bottomBarBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: p.border, width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x99000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(7, 6, 10, 6),
        child: Row(
          children: [
            // Avatar + Authentic Status Badge
            GestureDetector(
              onLongPress: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DiscordSettingsScreen(controller: ctrl),
                  ),
                );
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: NetworkImage(acc.avatarUrl(size: 96)),
                  ),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: DiscordStatusBadge(
                      status: ctrl.botStatus,
                      size: 15,
                      borderColor: p.bottomBarBg,
                      borderWidth: 2.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Display Name + Official APP Badge + Chevron + Status Subtitle
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
                          style: TextStyle(
                            color: p.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4.5, vertical: 1),
                        decoration: BoxDecoration(
                          color: DiscordPalette.blurple,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (acc.isVerifiedBot) ...[
                              const Icon(Icons.check_rounded,
                                  size: 10, color: Colors.white),
                              const SizedBox(width: 1),
                            ],
                            const Text(
                              'APP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 18,
                        color: p.textSecondary,
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
                    style: TextStyle(
                      color: p.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Right Notification Bell Pill (red badge ONLY when unread notifications > 0!)
            GestureDetector(
              onTap: () => _showNotificationsSheet(ctrl, p),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: p.elevatedBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      badgeCount > 0
                          ? Icons.notifications_rounded
                          : Icons.notifications_none_rounded,
                      color: p.textPrimary,
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

  List<DiscordChannel> _orderedVisibleGuildChannels(
    DiscordGuild guild,
    BotClientController ctrl,
  ) {
    final allChannels = guild.channels;
    final allCategoryIds =
        allChannels.where((c) => c.isCategory).map((c) => c.id).toSet();
    final categories = allChannels.where((c) => c.isCategory).toList()
      ..sort(DiscordChannel.compareCategories);

    final result = <DiscordChannel>[];
    final uncat = allChannels
        .where((c) =>
            (c.parentId == null || !allCategoryIds.contains(c.parentId)) &&
            c.isTopLevelChannel &&
            ctrl.canViewChannel(guild, c))
        .toList()
      ..sort(DiscordChannel.compareGuildChannels);
    result.addAll(uncat);

    for (final cat in categories) {
      final children = allChannels
          .where((c) =>
              c.parentId == cat.id &&
              c.isTopLevelChannel &&
              ctrl.canViewChannel(guild, c))
          .toList()
        ..sort(DiscordChannel.compareGuildChannels);
      result.addAll(children);
    }
    return result;
  }

  void _showChannelQuickSearch(DiscordGuild guild, DiscordPalette p) {
    final qCtrl = TextEditingController();
    String q = '';
    final orderedBase = _orderedVisibleGuildChannels(guild, widget.controller);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final filtered = orderedBase
              .where((c) => c.name.toLowerCase().contains(q.toLowerCase()))
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
                      prefixIcon:
                          Icon(Icons.search_rounded, color: p.textMuted),
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
                          leading: Icon(
                            ch.isForum
                                ? Icons.forum_outlined
                                : (ch.isStageVoice
                                    ? Icons.podcasts_rounded
                                    : (ch.isVoice
                                        ? Icons.volume_up_rounded
                                        : (ch.type == 5
                                            ? Icons.campaign_rounded
                                            : Icons.tag_rounded))),
                            color: p.textMuted,
                          ),
                          title: Text(ch.name,
                              style: TextStyle(color: p.textPrimary)),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            if (ch.isVoice) {
                              _openVoiceSheet(guild, ch);
                            } else {
                              _openChannelChat(ch.id, guildId: guild.id);
                            }
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

  void _showServerActionsSheet(DiscordGuild guild, DiscordPalette p) {
    final perms = widget.controller.currentChannelPermissions();
    final canManageChannels =
        DiscordPermissions.has(perms, DiscordPermissions.manageChannels);
    final canAudit =
        DiscordPermissions.has(perms, DiscordPermissions.viewAuditLog);

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                guild.name,
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: p.sidebarBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    if (canManageChannels)
                      ListTile(
                        leading: Icon(Icons.add_circle_outline,
                            color: p.textPrimary),
                        title: Text('建立頻道',
                            style: TextStyle(color: p.textPrimary)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showCreateChannelModal(guild, p);
                        },
                      ),
                    if (canAudit) ...[
                      if (canManageChannels)
                        Divider(height: 1, color: p.border),
                      ListTile(
                        leading: Icon(Icons.receipt_long_outlined,
                            color: p.textPrimary),
                        title: Text('檢視審計日誌',
                            style: TextStyle(color: p.textPrimary)),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showAuditLogModal(guild, p);
                        },
                      ),
                    ],
                    Divider(height: 1, color: p.border),
                    ListTile(
                      leading: Icon(Icons.copy_rounded,
                          color: p.textSecondary),
                      title: Text('複製伺服器 ID',
                          style: TextStyle(color: p.textPrimary)),
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: guild.id));
                        Navigator.of(ctx).pop();
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAuditLogModal(DiscordGuild guild, DiscordPalette p) {
    final rest = widget.controller.rest;
    if (rest == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, sCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                '審計日誌',
                style: TextStyle(
                  color: p.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Divider(height: 1, color: p.border),
            Expanded(
              child: FutureBuilder<List<AuditLogEntry>>(
                future: rest.getGuildAuditLogs(guild.id),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final entries = snap.data ?? const [];
                  if (entries.isEmpty) {
                    return Center(
                      child: Text('無審計紀錄或無檢視權限',
                          style: TextStyle(color: p.textMuted)),
                    );
                  }
                  return ListView.separated(
                    controller: sCtrl,
                    padding: const EdgeInsets.all(14),
                    itemCount: entries.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: p.border),
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      return ListTile(
                        dense: true,
                        title: Text(e.actionLabel,
                            style: TextStyle(color: p.textPrimary)),
                        subtitle: Text(
                          '執行者: ${e.userId ?? '-'} • 目標: ${e.targetId ?? '-'}${e.reason != null ? '\n原因: ${e.reason}' : ''}',
                          style: TextStyle(color: p.textMuted, fontSize: 12),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
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
                  if (created.isVoice) {
                    _openVoiceSheet(guild, created);
                  } else {
                    _openChannelChat(created.id, guildId: guild.id);
                  }
                } catch (_) {}
              },
              child: const Text('建立'),
            ),
          ],
        ),
      ),
    );
  }

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
    final allCategoryIds =
        allChannels.where((c) => c.isCategory).map((c) => c.id).toSet();
    final categories = allChannels.where((c) => c.isCategory).toList()
      ..sort(DiscordChannel.compareCategories);

    final uncategorized = allChannels
        .where((c) =>
            (c.parentId == null || !allCategoryIds.contains(c.parentId)) &&
            c.isTopLevelChannel &&
            ctrl.canViewChannel(guild, c))
        .toList()
      ..sort(DiscordChannel.compareGuildChannels);

    final channelWidgets = <Widget>[];
    for (final ch in uncategorized) {
      channelWidgets.add(_buildChannelRow(ctrl, p, guild, ch));
    }

    for (final cat in categories) {
      final children = allChannels
          .where((c) =>
              c.parentId == cat.id &&
              c.isTopLevelChannel &&
              ctrl.canViewChannel(guild, c))
          .toList()
        ..sort(DiscordChannel.compareGuildChannels);
      if (children.isEmpty) continue;

      final collapsed = ctrl.isCategoryCollapsed(cat.id);
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
          channelWidgets.add(_buildChannelRow(ctrl, p, guild, ch));
        }
      } else {
        // Discord behavior: keep unread, selected, or active/non-empty voice channels visible even when category is collapsed!
        for (final ch in children) {
          final hasVoiceUsers =
              ch.isVoice && guild.voiceStatesForChannel(ch.id).isNotEmpty;
          if (ch.id == ctrl.selectedChannelId ||
              ch.id == ctrl.activeVoiceChannelId ||
              hasVoiceUsers ||
              ctrl.unreadChannelIds.contains(ch.id)) {
            channelWidgets.add(_buildChannelRow(ctrl, p, guild, ch));
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 92),
      children: [
        // Server Header (checks REAL guild.features for badges & Community status!)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showServerActionsSheet(guild, p),
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
                    if (guild.isVerified || guild.isPartnered) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.verified_rounded,
                        size: 17,
                        color: guild.isVerified
                            ? DiscordPalette.green
                            : DiscordPalette.blurple,
                      ),
                    ],
                    const SizedBox(width: 3),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 19,
                      color: p.textMuted,
                    ),
                  ],
                ),
              ),
              if (guild.memberCount != null) ...[
                const SizedBox(height: 3),
                Text(
                  guild.isCommunity
                      ? '${_formatMemberCount(guild.memberCount!)} 位成員 • 社群'
                      : '${_formatMemberCount(guild.memberCount!)} 位成員',
                  style: TextStyle(
                    color: p.textMuted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 12),

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

        // ONLY shown on real Community / Onboarding servers!
        if (guild.hasOnboarding) ...[
          InkWell(
            onTap: () => _showChannelQuickSearch(guild, p),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.manage_search_rounded,
                      size: 20, color: p.textMuted),
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
                ],
              ),
            ),
          ),
          Divider(height: 1, color: p.border),
        ],

        const SizedBox(height: 6),
        ...channelWidgets,
      ],
    );
  }

  /// Authentic Discord Channel Row:
  /// - Left white semicircle dot STRICTLY ONLY when `unread` is true (NEVER on `selected`!)
  /// - Voice channels open the Join Voice / Active Voice Room sheet on tap, and render
  ///   connected voice participants directly underneath the channel row!
  Widget _buildChannelRow(
    BotClientController ctrl,
    DiscordPalette p,
    DiscordGuild guild,
    DiscordChannel ch,
  ) {
    final isConnectedVoice =
        ch.isVoice && ctrl.activeVoiceChannelId == ch.id;
    final selected =
        (!ch.isVoice && ctrl.selectedChannelId == ch.id) || isConnectedVoice;
    final unread =
        ctrl.selectedChannelId != ch.id && ctrl.unreadChannelIds.contains(ch.id);
    final isRules = guild.rulesChannelId == ch.id;
    final isLocked = ch.permissionOverwrites.any(
      (ow) =>
          ow.id == guild.id &&
          DiscordPermissions.has(ow.deny, DiscordPermissions.viewChannel),
    );

    final voiceStates =
        ch.isVoice ? guild.voiceStatesForChannel(ch.id) : const <VoiceState>[];

    final iconColor = isConnectedVoice
        ? DiscordPalette.green
        : ((selected || unread) ? Colors.white : p.textMuted);

    Widget leadingIcon;
    if (isRules) {
      leadingIcon =
          Icon(Icons.fact_check_outlined, size: 20, color: iconColor);
    } else if (ch.isForum) {
      leadingIcon = Icon(Icons.forum_outlined, size: 20, color: iconColor);
    } else if (ch.type == 5) {
      leadingIcon = Icon(Icons.campaign_rounded, size: 21, color: iconColor);
    } else if (ch.isStageVoice) {
      leadingIcon = Icon(Icons.podcasts_rounded, size: 20, color: iconColor);
    } else if (ch.isVoice) {
      leadingIcon = Icon(Icons.volume_up_rounded, size: 20, color: iconColor);
    } else {
      leadingIcon = DiscordChannelHashIcon(
        locked: isLocked,
        color: iconColor,
        size: 21,
      );
    }

    final rowStack = Stack(
      alignment: Alignment.centerLeft,
      children: [
        // White semicircle unread dot ONLY when channel genuinely has unread new messages!
        if (unread)
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
            onTap: () {
              if (ch.isVoice) {
                _openVoiceSheet(guild, ch);
              } else {
                _openChannelChat(ch.id, guildId: guild.id);
              }
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                        color: isConnectedVoice
                            ? DiscordPalette.green
                            : ((selected || unread)
                                ? Colors.white
                                : p.textMuted),
                        fontSize: 15.5,
                        fontWeight: (selected || unread || isConnectedVoice)
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (ch.isVoice &&
                      (ch.userLimit > 0 || voiceStates.isNotEmpty)) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: p.elevatedBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        ch.userLimit > 0
                            ? '${voiceStates.length.toString().padLeft(2, '0')}/${ch.userLimit.toString().padLeft(2, '0')}'
                            : '${voiceStates.length}',
                        style: TextStyle(
                          color: p.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  if (ch.isVoice &&
                      (voiceStates.isNotEmpty ||
                          isConnectedVoice ||
                          unread)) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _openChannelChat(ch.id, guildId: guild.id),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 15.5,
                          color: unread ? Colors.white : p.textMuted,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (!ch.isVoice || voiceStates.isEmpty) {
      return rowStack;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        rowStack,
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ValueListenableBuilder<Set<String>>(
            valueListenable: ctrl.speakingUserIdsNotifier,
            builder: (_, speakingIds, __) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: voiceStates
                    .map((vs) => _buildConnectedVoiceMemberRow(
                          ctrl: ctrl,
                          p: p,
                          guild: guild,
                          channel: ch,
                          vs: vs,
                          isSpeaking: speakingIds.contains(vs.userId),
                        ))
                    .toList(growable: false),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConnectedVoiceMemberRow({
    required BotClientController ctrl,
    required DiscordPalette p,
    required DiscordGuild guild,
    required DiscordChannel channel,
    required VoiceState vs,
    required bool isSpeaking,
  }) {
    final acc = ctrl.activeAccount;
    final isSelfBot = acc != null && vs.userId == acc.id;
    final member = vs.member ?? guild.cachedMembers[vs.userId];
    final name = isSelfBot
        ? (member?.effectiveName ?? acc.displayName)
        : (member?.effectiveName ?? 'User ${vs.userId}');
    final avatarUrl = isSelfBot
        ? acc.avatarUrl(size: 64)
        : (member != null
            ? member.user.avatarUrl(size: 64)
            : 'https://cdn.discordapp.com/embed/avatars/${((BigInt.tryParse(vs.userId) ?? BigInt.zero) >> 22).toInt().abs() % 6}.png');

    return InkWell(
      onTap: () => _openVoiceSheet(guild, channel),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(38, 3.5, 16, 3.5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking ? DiscordPalette.green : Colors.transparent,
                  width: 1.8,
                ),
              ),
              child: CircleAvatar(
                radius: 10.5,
                backgroundImage: NetworkImage(avatarUrl),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSpeaking ? Colors.white : p.textSecondary,
                  fontSize: 13.5,
                  fontWeight: isSpeaking ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (vs.selfStream) ...[
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding:
                    const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1),
                decoration: BoxDecoration(
                  color: DiscordPalette.danger,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '直播',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
            if (vs.isMuted) ...[
              const SizedBox(width: 4),
              Icon(Icons.mic_off_rounded, size: 14, color: p.textMuted),
            ],
            if (vs.isDeafened) ...[
              const SizedBox(width: 4),
              Icon(Icons.headset_off_rounded, size: 14, color: p.textMuted),
            ],
          ],
        ),
      ),
    );
  }

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
                    final selected = ctrl.selectedChannelId == ch.id;
                    final unread =
                        !selected && ctrl.unreadChannelIds.contains(ch.id);

                    return Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        if (unread)
                          Container(
                            width: 4,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.horizontal(
                                  right: Radius.circular(4)),
                            ),
                          ),
                        ListTile(
                          selected: selected,
                          selectedTileColor: p.selectedChannelBg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          leading: CircleAvatar(
                            radius: 21,
                            backgroundImage: user != null
                                ? NetworkImage(user.avatarUrl(size: 96))
                                : null,
                            child: user == null
                                ? const Icon(Icons.person)
                                : null,
                          ),
                          title: Text(
                            ch.displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: (unread || selected)
                                  ? Colors.white
                                  : p.textSecondary,
                              fontWeight: unread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          subtitle: Text(
                            user != null ? user.username : '私人訊息',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                TextStyle(color: p.textMuted, fontSize: 12.5),
                          ),
                          onTap: () => _openChannelChat(ch.id, guildId: null),
                        ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Center Chat / Forum Posts Pane
class _DiscordChatPane extends StatefulWidget {
  final BotClientController controller;
  final DiscordPalette palette;
  final bool showBackButton;
  final VoidCallback onBack;
  final VoidCallback onToggleRightDrawer;
  final VoidCallback onEnsureCenterChat;
  final void Function(DiscordGuild guild, DiscordChannel channel)
      onOpenVoiceRoom;
  final void Function(String threadChannelId) onSelectForumPost;
  final Future<void> Function(String userId) onOpenDmFromChat;

  const _DiscordChatPane({
    required this.controller,
    required this.palette,
    required this.showBackButton,
    required this.onBack,
    required this.onToggleRightDrawer,
    required this.onEnsureCenterChat,
    required this.onOpenVoiceRoom,
    required this.onSelectForumPost,
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
  bool _showJumpBottom = false;
  String _slashPrefix = '';

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _composerCtrl.addListener(_onComposerChanged);
  }

  @override
  void dispose() {
    _scrollCtrl.removeListener(_onScroll);
    _composerCtrl.removeListener(_onComposerChanged);
    _scrollCtrl.dispose();
    _composerCtrl.dispose();
    super.dispose();
  }

  void _onComposerChanged() {
    final raw = _composerCtrl.text;
    final nonEmpty = raw.trim().isNotEmpty;
    final nextSlash = raw.startsWith('/') && !raw.contains('\n') ? raw : '';
    if (nonEmpty != _hasText || nextSlash != _slashPrefix) {
      setState(() {
        _hasText = nonEmpty;
        _slashPrefix = nextSlash;
      });
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 250) {
      widget.controller.loadOlderMessages();
    }
    final shouldShowJump = pos.pixels > 380;
    if (shouldShowJump != _showJumpBottom) {
      setState(() => _showJumpBottom = shouldShowJump);
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
        await widget.controller.editChatMessage(target.id, newContent: text);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
      }
      return;
    }

    if (text.isEmpty &&
        (embeds == null || embeds.isEmpty) &&
        _pendingAttachmentBytes == null) {
      return;
    }

    // Check built-in DiscordBotClient commands (/ping, /purge, /switch)
    if (embeds == null &&
        _pendingAttachmentBytes == null &&
        text.startsWith('/')) {
      setState(() {
        _sending = true;
        _composerCtrl.clear();
      });
      try {
        final feedback =
            await widget.controller.tryExecuteBuiltInCommand(text);
        if (feedback != null) {
          if (mounted && feedback != 'Pong!') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(feedback)),
            );
          }
          return;
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e')),
          );
        }
        return;
      } finally {
        if (mounted) setState(() => _sending = false);
      }
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

  Widget _buildSlashAutocompleteBar(DiscordPalette p) {
    if (_slashPrefix.isEmpty) return const SizedBox.shrink();

    const commands = [
      ('/ping', '傳送 Pong! 測試機器人回應'),
      ('/purge ', '批次刪除頻道內近期訊息 (2–100 則)'),
      ('/switch shard ', '切換連線的 Gateway Shard ID'),
      ('/switch guild ', '根據伺服器 ID 自動計算並切換分片'),
    ];

    final matches = commands
        .where((c) => c.$1.startsWith(_slashPrefix.split(' ').first))
        .toList();
    if (matches.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 4),
      decoration: BoxDecoration(
        color: p.sidebarBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: matches.map((m) {
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: const Icon(Icons.terminal_rounded,
                size: 18, color: DiscordPalette.blurple),
            title: Text(
              m.$1.trim(),
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              m.$2,
              style: TextStyle(color: p.textMuted, fontSize: 11.5),
            ),
            onTap: () {
              _composerCtrl.text = m.$1;
              _composerCtrl.selection = TextSelection.fromPosition(
                TextPosition(offset: _composerCtrl.text.length),
              );
            },
          );
        }).toList(),
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
                  onTap: (channel.isDm && dmUser != null)
                      ? () => showUserProfileSheet(
                            context,
                            controller: ctrl,
                            initialUser: dmUser,
                            guildId: null,
                            onNavigateToDm: widget.onEnsureCenterChat,
                          )
                      : widget.onToggleRightDrawer,
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
                            channel.isForum
                                ? Icons.forum_outlined
                                : (channel.isVoice
                                    ? Icons.volume_up_rounded
                                    : Icons.tag_rounded),
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
              if (channel.isVoice && guild != null)
                IconButton(
                  tooltip: ctrl.activeVoiceChannelId == channel.id
                      ? '開啟語音房間'
                      : '加入語音',
                  icon: Icon(
                    Icons.volume_up_rounded,
                    color: ctrl.activeVoiceChannelId == channel.id
                        ? DiscordPalette.green
                        : p.textSecondary,
                    size: 21,
                  ),
                  onPressed: () => widget.onOpenVoiceRoom(guild, channel),
                ),
              IconButton(
                icon: Icon(
                  channel.isDm ? Icons.more_horiz_rounded : Icons.group_rounded,
                  color: p.textSecondary,
                  size: 22,
                ),
                onPressed: widget.onToggleRightDrawer,
              ),
            ],
          ),
        ),

        // Forum Posts View vs Standard 120fps Chat Feed
        Expanded(
          child: channel.isForum
              ? FutureBuilder<List<DiscordChannel>>(
                  future: ctrl.fetchForumThreads(channel),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final posts = snap.data ?? const [];
                    if (posts.isEmpty) {
                      return Center(
                        child: Text('此論壇頻道目前尚無貼文',
                            style: TextStyle(color: p.textMuted)),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: posts.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, idx) {
                        final post = posts[idx];
                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => widget.onSelectForumPost(post.id),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: p.sidebarBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: p.border, width: 0.7),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.chat_outlined,
                                    size: 20, color: p.textSecondary),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    post.name,
                                    style: TextStyle(
                                      color: p.textPrimary,
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Icon(Icons.chevron_right_rounded,
                                    color: p.textMuted),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                )
              : Stack(
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: ctrl.loadingMessagesNotifier,
                      builder: (_, loading, __) {
                        if (loading) {
                          return const Center(
                              child: CircularProgressIndicator());
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (channel.isDm && dmUser != null)
                                            GestureDetector(
                                              onTap: () => showUserProfileSheet(
                                                context,
                                                controller: ctrl,
                                                initialUser: dmUser,
                                                guildId: null,
                                                onNavigateToDm:
                                                    widget.onEnsureCenterChat,
                                              ),
                                              child: CircleAvatar(
                                                radius: 34,
                                                backgroundImage: NetworkImage(
                                                    dmUser.avatarUrl(
                                                        size: 128)),
                                              ),
                                            )
                                          else
                                            Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                color: p.inputBg,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                channel.isDm
                                                    ? Icons
                                                        .alternate_email_rounded
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
                                          if (channel.isDm && dmUser != null) ...[
                                            const SizedBox(height: 12),
                                            OutlinedButton.icon(
                                              onPressed: () =>
                                                  showUserProfileSheet(
                                                context,
                                                controller: ctrl,
                                                initialUser: dmUser,
                                                guildId: null,
                                                onNavigateToDm:
                                                    widget.onEnsureCenterChat,
                                              ),
                                              icon: const Icon(
                                                  Icons.person_outline_rounded,
                                                  size: 17),
                                              label: const Text('檢視個人資料'),
                                            ),
                                          ],
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                bool compact = false;
                                bool showDateDivider = false;
                                if (index + 1 < messages.length) {
                                  final older = messages[index + 1];
                                  final sameDay = msg.timestamp.year ==
                                          older.timestamp.year &&
                                      msg.timestamp.month ==
                                          older.timestamp.month &&
                                      msg.timestamp.day == older.timestamp.day;
                                  showDateDivider = !sameDay;
                                  if (sameDay &&
                                      older.author.id == msg.author.id &&
                                      msg.referencedMessage == null &&
                                      msg.timestamp
                                              .difference(older.timestamp)
                                              .inMinutes
                                              .abs() <
                                          7) {
                                    compact = true;
                                  }
                                } else {
                                  showDateDivider = true;
                                }

                                return MessageTile(
                                  key: ValueKey(msg.id),
                                  message: msg,
                                  compact: compact,
                                  showDateDivider: showDateDivider,
                                  palette: p,
                                  guild: guild,
                                  currentBotUserId:
                                      ctrl.activeAccount?.id ?? '',
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
                                  onEditEmbed: (m) {
                                    if (m.embeds.isEmpty) return;
                                    showModalBottomSheet<void>(
                                      context: context,
                                      isScrollControlled: true,
                                      builder: (_) => EmbedComposerSheet(
                                        palette: p,
                                        initialEmbed: m.embeds.first,
                                        onSend: (updatedEmbed, _) async {
                                          try {
                                            await ctrl.editChatMessage(
                                              m.id,
                                              newContent: m.content,
                                              embeds: [updatedEmbed],
                                            );
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                    content: Text('$e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    );
                                  },
                                  onDelete: (m) async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        backgroundColor: p.cardBg,
                                        title: const Text('刪除訊息'),
                                        content:
                                            const Text('確定要刪除此則訊息嗎？'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(false),
                                            child: const Text('取消'),
                                          ),
                                          FilledButton(
                                            style: FilledButton.styleFrom(
                                              backgroundColor:
                                                  DiscordPalette.danger,
                                            ),
                                            onPressed: () =>
                                                Navigator.of(ctx).pop(true),
                                            child: const Text('刪除'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await ctrl.deleteChatMessage(m.id);
                                      } catch (_) {}
                                    }
                                  },
                                  onTogglePin: (m) async {
                                    try {
                                      if (m.pinned) {
                                        await ctrl.rest?.unpinMessage(
                                            m.channelId, m.id);
                                      } else {
                                        await ctrl.rest
                                            ?.pinMessage(m.channelId, m.id);
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
                                  onOpenUserProfile: (u, {member}) =>
                                      showUserProfileSheet(
                                    context,
                                    controller: ctrl,
                                    initialUser: u,
                                    initialMember: member,
                                    guildId: guild?.id,
                                    onNavigateToDm: widget.onEnsureCenterChat,
                                  ),
                                  onTapUserMention: (uid) =>
                                      showUserProfileById(
                                    context,
                                    controller: ctrl,
                                    userId: uid,
                                    guildId: guild?.id,
                                    onNavigateToDm: widget.onEnsureCenterChat,
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),

                    // Jump-to-Latest Floating Pill
                    if (_showJumpBottom)
                      Positioned(
                        right: 14,
                        bottom: 10,
                        child: GestureDetector(
                          onTap: () {
                            if (_scrollCtrl.hasClients) {
                              _scrollCtrl.animateTo(
                                0,
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                              );
                            }
                          },
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: p.sidebarBg,
                              shape: BoxShape.circle,
                              border: Border.all(color: p.border),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x66000000),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: p.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                  ],
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

        // Built-in Slash Command Autocomplete Bar
        _buildSlashAutocompleteBar(p),

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
                            : '回覆 ${_replyTarget!.authorDisplayName(guild)}'),
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

        // Bottom Chat Composer Bar (hidden on Forum root index)
        if (!channel.isForum)
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
                            style: TextStyle(
                                color: p.textPrimary, fontSize: 15),
                            decoration: InputDecoration(
                              hintText: canSend
                                  ? (channel.isDm
                                      ? '傳送訊息給 @${channel.displayTitle}'
                                      : '傳送訊息至 #${channel.name}')
                                  : '您沒有在此頻道發送訊息的權限',
                              hintStyle: TextStyle(
                                  color: p.textMuted, fontSize: 14.5),
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
                if (_hasText ||
                    _pendingAttachmentBytes != null ||
                    _sending) ...[
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
