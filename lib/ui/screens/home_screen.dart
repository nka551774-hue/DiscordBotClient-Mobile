import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/discord_icons.dart';
import '../widgets/embed_composer_sheet.dart';
import '../widgets/guild_tools_sheet.dart';
import '../widgets/message_tile.dart';
import '../widgets/settings_sheet.dart';

/// 1:1 Official Discord Mobile App UI:
/// - 4 Bottom Tabs: Servers, Messages, Notifications, You
/// - Full-screen slide-in Chat View on channel/DM tap (with Android/iOS back gesture)
class HomeScreen extends StatefulWidget {
  final BotClientController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0; // 0: Servers, 1: Messages, 2: Notifications, 3: You
  bool _chatOpenOnPhone = false;
  final _dmSearchCtrl = TextEditingController();
  String _dmFilter = '';

  @override
  void dispose() {
    _dmSearchCtrl.dispose();
    super.dispose();
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

  /// Exact "New Message" by User ID modal from VencordDBCPlugin/utils/create-dm-by-id.ts
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
                        child: Text('Cancel',
                            style: TextStyle(color: p.textSecondary)),
                      ),
                      const Expanded(
                        child: Text(
                          'New Message',
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
                                if (uid ==
                                    widget.controller.activeAccount?.id) {
                                  setModalState(() {
                                    errorText =
                                        'You cannot open a DM with yourself.';
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
                                  setState(() {
                                    _currentTab = 1;
                                    _chatOpenOnPhone = true;
                                  });
                                } catch (e) {
                                  setModalState(() {
                                    opening = false;
                                    errorText = 'Could not open DM: $e';
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
                            : const Text('Chat'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      'Choose one person to start a DM.',
                      style: TextStyle(color: p.textMuted, fontSize: 12.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: idCtrl,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: TextStyle(color: p.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      prefixText: 'To: ',
                      prefixStyle: TextStyle(color: p.textMuted, fontSize: 15),
                      hintText: 'Search or enter a User ID',
                      hintStyle: TextStyle(color: p.textMuted, fontSize: 15),
                      helperText: errorText ??
                          'Select one person or enter their User ID.',
                      helperStyle: TextStyle(
                        color: errorText != null
                            ? DiscordPalette.red
                            : p.textMuted,
                        fontSize: 12,
                      ),
                      filled: true,
                      fillColor: p.elevatedBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
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

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
    final isWide = MediaQuery.of(context).size.width >= 760;

    if (isWide) {
      // Tablet / Landscape split layout
      return Scaffold(
        backgroundColor: p.chatBg,
        body: SafeArea(
          child: Row(
            children: [
              SizedBox(
                width: 340,
                child: Column(
                  children: [
                    Expanded(child: _buildActiveTabBody(ctrl, p)),
                    _buildDiscordBottomBar(ctrl, p),
                  ],
                ),
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
                    setState(() => _currentTab = 1);
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Phone layout: 1:1 Official Discord Mobile (Tabs <-> Slide-in Full-Screen Chat)
    if (_chatOpenOnPhone && ctrl.selectedChannel != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) {
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
                setState(() {
                  _currentTab = 1;
                  _chatOpenOnPhone = true;
                });
              },
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: p.sidebarBg,
      body: SafeArea(
        child: _buildActiveTabBody(ctrl, p),
      ),
      bottomNavigationBar: _buildDiscordBottomBar(ctrl, p),
    );
  }

  Widget _buildActiveTabBody(BotClientController ctrl, DiscordPalette p) {
    switch (_currentTab) {
      case 0:
        return _ServersTabView(
          controller: ctrl,
          palette: p,
          onChannelTap: (ch) => _openChannelChat(ch.id, guildId: ch.guildId),
        );
      case 1:
        return _buildMessagesTab(ctrl, p);
      case 2:
        return _buildNotificationsTab(ctrl, p);
      case 3:
        return _YouProfileTabView(controller: ctrl, palette: p);
      default:
        return const SizedBox.shrink();
    }
  }

  /// TAB 1: Official Discord Mobile "Messages" View
  Widget _buildMessagesTab(BotClientController ctrl, DiscordPalette p) {
    final allDms = ctrl.dmChannels;
    final dms = _dmFilter.isEmpty
        ? allDms
        : allDms
            .where((c) =>
                c.displayTitle.toLowerCase().contains(_dmFilter.toLowerCase()))
            .toList();

    return Container(
      color: p.chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
            child: Row(
              children: [
                Text(
                  'Messages',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.inputBg,
                    foregroundColor: p.textPrimary,
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () => _showNewMessageModal(p),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                  label: const Text('New Message',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),

          // Search Bar Pill
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              controller: _dmSearchCtrl,
              onChanged: (v) => setState(() => _dmFilter = v),
              style: TextStyle(color: p.textPrimary, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search',
                hintStyle: TextStyle(color: p.textMuted, fontSize: 14.5),
                prefixIcon:
                    Icon(Icons.search_rounded, color: p.textMuted, size: 20),
                filled: true,
                fillColor: p.elevatedBg,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: dms.isEmpty
                ? Center(
                    child: Text(
                      'No direct messages yet',
                      style: TextStyle(color: p.textMuted, fontSize: 14),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
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
                          radius: 22,
                          backgroundImage: user != null
                              ? NetworkImage(user.avatarUrl(size: 96))
                              : null,
                          child: user == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                ch.displayTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread
                                      ? p.textPrimary
                                      : p.textSecondary,
                                  fontWeight: unread
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 15.5,
                                ),
                              ),
                            ),
                            if (user != null && user.bot)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4.5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: DiscordPalette.blurple,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: const Text(
                                  'APP',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          user != null ? '@${user.username}' : 'Direct Message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.textMuted, fontSize: 13),
                        ),
                        onTap: () => _openChannelChat(ch.id, guildId: null),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  /// TAB 2: Official Discord Mobile "Notifications" View
  Widget _buildNotificationsTab(BotClientController ctrl, DiscordPalette p) {
    final items = ctrl.notifications;

    return Container(
      color: p.chatBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
            child: Text(
              'Notifications',
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
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
                            size: 48, color: p.textMuted),
                        const SizedBox(height: 10),
                        Text(
                          'Nothing to see here yet',
                          style: TextStyle(
                            color: p.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: p.border),
                    itemBuilder: (_, idx) {
                      final msg = items[idx];
                      final guild = ctrl.findGuildById(msg.guildId);
                      final ch = ctrl.findChannelById(msg.channelId);
                      final whereLabel = guild != null
                          ? '${guild.name}  •  #${ch?.name ?? 'channel'}'
                          : 'Direct Message';

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage:
                              NetworkImage(msg.author.avatarUrl(size: 64)),
                        ),
                        title: Text(
                          whereLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(color: p.textMuted, fontSize: 12),
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
                                  ? '[Attachment / Embed]'
                                  : msg.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: p.textSecondary, fontSize: 13.5),
                            ),
                          ],
                        ),
                        onTap: () async {
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
      ),
    );
  }

  /// Official Discord Mobile Bottom Navigation Bar: Servers | Messages | Notifications | You
  Widget _buildDiscordBottomBar(BotClientController ctrl, DiscordPalette p) {
    final acc = ctrl.activeAccount;
    final statusColor = _statusColor(ctrl.botStatus);

    return Container(
      decoration: BoxDecoration(
        color: p.bottomBarBg,
        border: Border(top: BorderSide(color: p.border, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 58,
          child: Row(
            children: [
              _bottomNavItem(
                p,
                index: 0,
                label: 'Servers',
                iconWidget: DiscordClydeLogo(
                  size: 23,
                  color: _currentTab == 0 ? p.textPrimary : p.textMuted,
                ),
              ),
              _bottomNavItem(
                p,
                index: 1,
                label: 'Messages',
                iconWidget: Icon(
                  _currentTab == 1
                      ? Icons.chat_bubble_rounded
                      : Icons.chat_bubble_outline_rounded,
                  size: 22,
                  color: _currentTab == 1 ? p.textPrimary : p.textMuted,
                ),
              ),
              _bottomNavItem(
                p,
                index: 2,
                label: 'Notifications',
                badgeCount: ctrl.notifications.length,
                iconWidget: Icon(
                  _currentTab == 2
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                  size: 24,
                  color: _currentTab == 2 ? p.textPrimary : p.textMuted,
                ),
              ),
              _bottomNavItem(
                p,
                index: 3,
                label: 'You',
                iconWidget: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _currentTab == 3
                              ? p.textPrimary
                              : Colors.transparent,
                          width: 1.5,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 11,
                        backgroundImage: acc != null
                            ? NetworkImage(acc.avatarUrl(size: 64))
                            : null,
                      ),
                    ),
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: p.bottomBarBg, width: 1.8),
                        ),
                      ),
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

  Widget _bottomNavItem(
    DiscordPalette p, {
    required int index,
    required String label,
    required Widget iconWidget,
    int badgeCount = 0,
  }) {
    final selected = _currentTab == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (index == 0 &&
              widget.controller.selectedGuildId == null &&
              widget.controller.guilds.isNotEmpty) {
            widget.controller
                .selectGuild(widget.controller.guilds.first.id);
          }
          setState(() => _currentTab = index);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  height: 25,
                  child: Center(child: iconWidget),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: DiscordPalette.danger,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? p.textPrimary : p.textMuted,
                fontSize: 10.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String st) {
    switch (st) {
      case 'idle':
        return DiscordPalette.yellow;
      case 'dnd':
        return DiscordPalette.danger;
      case 'invisible':
        return DiscordPalette.greyStatus;
      default:
        return DiscordPalette.green;
    }
  }
}

/// TAB 0: Official Discord Mobile "Servers" View (Left 72px Guild Rail + Rounded Channel Sheet)
class _ServersTabView extends StatelessWidget {
  final BotClientController controller;
  final DiscordPalette palette;
  final void Function(DiscordChannel ch) onChannelTap;

  const _ServersTabView({
    required this.controller,
    required this.palette,
    required this.onChannelTap,
  });

  Future<void> _showCreateChannelDialog(
    BuildContext context,
    DiscordGuild guild,
  ) async {
    final nameCtrl = TextEditingController();
    int type = 0;
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: palette.cardBg,
          title: const Text('Create Channel'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                value: type,
                dropdownColor: palette.cardBg,
                items: const [
                  DropdownMenuItem(value: 0, child: Text('Text Channel')),
                  DropdownMenuItem(value: 2, child: Text('Voice Channel')),
                ],
                onChanged: (v) {
                  if (v != null) setDlg(() => type = v);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'new-channel'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                Navigator.of(ctx).pop();
                try {
                  final created = await controller.rest!
                      .createGuildChannel(guild.id, name: name, type: type);
                  onChannelTap(created);
                } catch (_) {}
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final guilds = controller.guilds;
    final selectedGuild = controller.selectedGuild ??
        (guilds.isNotEmpty ? guilds.first : null);
    final iconPx = controller.ecoSettings.avatarSize;

    return Container(
      color: palette.railBg,
      child: Row(
        children: [
          // Left Vertical Server Icons Rail (72px)
          SizedBox(
            width: 72,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: guilds.length,
              itemBuilder: (_, idx) {
                final g = guilds[idx];
                final selected = selectedGuild?.id == g.id;
                final iconUrl = g.iconUrl(size: iconPx);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: GestureDetector(
                    onTap: () => controller.selectGuild(g.id),
                    child: Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 4,
                          height: selected ? 36 : 0,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.horizontal(
                                right: Radius.circular(4)),
                          ),
                        ),
                        const Spacer(),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: 48,
                          height: 48,
                          clipBehavior: Clip.antiAlias,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? DiscordPalette.blurple
                                : palette.sidebarBg,
                            borderRadius:
                                BorderRadius.circular(selected ? 15 : 24),
                          ),
                          child: iconUrl != null
                              ? Image.network(
                                  iconUrl,
                                  width: 48,
                                  height: 48,
                                  cacheWidth: iconPx,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    g.initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                )
                              : Text(
                                  g.initials,
                                  style: const TextStyle(
                                    color: Colors.white,
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
              },
            ),
          ),

          // Right Rounded Server Channel Panel (1:1 Discord Mobile!)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: palette.sidebarBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18),
                ),
              ),
              child: selectedGuild == null
                  ? Center(
                      child: Text(
                        'No servers joined',
                        style: TextStyle(color: palette.textMuted),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Server Name Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  selectedGuild.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(Icons.add_rounded,
                                    color: palette.textSecondary, size: 22),
                                onPressed: () => _showCreateChannelDialog(
                                    context, selectedGuild),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: palette.border),
                        Expanded(
                          child: _buildCategorizedChannels(selectedGuild),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorizedChannels(DiscordGuild guild) {
    final allChannels = guild.channels;
    final categories = allChannels.where((c) => c.isCategory).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final uncategorized = allChannels
        .where((c) =>
            !c.isCategory &&
            c.parentId == null &&
            c.isMessageable &&
            controller.canViewChannel(guild, c))
        .toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    final items = <Widget>[];
    for (final ch in uncategorized) {
      items.add(_channelRow(ch));
    }

    for (final cat in categories) {
      final children = allChannels
          .where((c) =>
              !c.isCategory &&
              c.parentId == cat.id &&
              c.isMessageable &&
              controller.canViewChannel(guild, c))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      if (children.isEmpty) continue;

      final collapsed = controller.isCategoryCollapsed(cat.id);
      items.add(
        InkWell(
          onTap: () => controller.toggleCategoryCollapse(cat.id),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 10, 4),
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? Icons.keyboard_arrow_right_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: palette.textMuted,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text(
                    cat.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!collapsed) {
        for (final ch in children) {
          items.add(_channelRow(ch));
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      children: items,
    );
  }

  Widget _channelRow(DiscordChannel ch) {
    final selected = controller.selectedChannelId == ch.id;
    final unread = controller.unreadChannelIds.contains(ch.id);

    IconData icon = Icons.tag_rounded;
    if (ch.type == 2) icon = Icons.volume_up_rounded;
    if (ch.type == 5) icon = Icons.campaign_rounded;
    if (ch.type == 11 || ch.type == 12) icon = Icons.subdirectory_arrow_right;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChannelTap(ch),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? palette.inputBg : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected || unread
                    ? palette.textPrimary
                    : palette.textMuted,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  ch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected || unread
                        ? palette.textPrimary
                        : palette.textSecondary,
                    fontWeight:
                        selected || unread ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ),
              if (unread && !selected)
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// TAB 3: Official Discord Mobile "You" Profile Screen
class _YouProfileTabView extends StatelessWidget {
  final BotClientController controller;
  final DiscordPalette palette;

  const _YouProfileTabView({
    required this.controller,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final acc = controller.activeAccount;
    if (acc == null) return const SizedBox.shrink();

    final created = snowflakeCreatedAt(acc.id);
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final createdStr =
        '${months[created.month - 1]} ${created.day}, ${created.year}';

    Color statusDot = DiscordPalette.green;
    if (controller.botStatus == 'idle') statusDot = DiscordPalette.yellow;
    if (controller.botStatus == 'dnd') statusDot = DiscordPalette.danger;
    if (controller.botStatus == 'invisible') {
      statusDot = DiscordPalette.greyStatus;
    }

    return Container(
      color: palette.sidebarBg,
      child: ListView(
        children: [
          // Top Banner + Gear Icon + Avatar Overlap (1:1 Discord Mobile "You")
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 128,
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5865F2), Color(0xFF343C99)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 14,
                child: Row(
                  children: [
                    _bannerCircleBtn(
                      icon: Icons.swap_horiz_rounded,
                      onTap: () => showSwitchAccountsSheet(context, controller),
                    ),
                    const SizedBox(width: 8),
                    _bannerCircleBtn(
                      icon: Icons.settings_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                DiscordSettingsScreen(controller: controller),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Positioned(
                left: 18,
                bottom: -42,
                child: GestureDetector(
                  onTap: () => showDiscordStatusSheet(context, controller),
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: palette.sidebarBg,
                          shape: BoxShape.circle,
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage:
                              NetworkImage(acc.avatarUrl(size: 128)),
                        ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: statusDot,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: palette.sidebarBg, width: 4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 52),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        acc.displayName,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: DiscordPalette.blurple,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'APP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  acc.username,
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 16),

                // Edit Status Pill Button
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: DiscordPalette.blurple,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    onPressed: () =>
                        showDiscordStatusSheet(context, controller),
                    icon: const Icon(Icons.circle_notifications_outlined,
                        size: 18),
                    label: Text(
                      controller.botActivityName.isEmpty
                          ? 'Edit Status'
                          : controller.botActivityName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Member Since Card (matching Discord Mobile You tab)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.chatBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discord Member Since',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        createdStr,
                        style: TextStyle(
                          color: palette.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bannerCircleBtn({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: const BoxDecoration(
          color: Color(0x77000000),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}

/// Full-screen 1:1 Discord Mobile Chat View
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
                  'Pinned Messages',
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
                          "This channel doesn't have any pinned messages... yet.",
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
                            m.content.isEmpty ? '[Embed / Attachment]' : m.content,
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
          'Select a channel',
          style: TextStyle(color: p.textMuted, fontSize: 15),
        ),
      );
    }

    final dmUser = channel.dmRecipient;

    return Column(
      children: [
        // 1:1 Discord Mobile Top Chat Header
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

        // Virtualized 120fps Chat Feed
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
                                      : 'Welcome to #${channel.name}!',
                                  style: TextStyle(
                                    color: p.textPrimary,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  channel.isDm
                                      ? 'This is the beginning of your direct message history with ${channel.displayTitle}.'
                                      : 'This is the start of the #${channel.name} channel.',
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
                        ? 'Editing Message'
                        : (_pendingAttachmentName != null
                            ? 'Attachment: $_pendingAttachmentName'
                            : 'Replying to ${_replyTarget!.author.displayName}'),
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

        // 1:1 Discord Mobile Bottom Chat Composer Bar
        Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 9),
          decoration: BoxDecoration(
            color: p.chatBg,
            border: Border(top: BorderSide(color: p.border, width: 0.5)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Left Circular "+" Button
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

              // Rounded Pill Input + Inline VencordDBCPlugin Embed Button
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
                                    ? 'Message @${channel.displayTitle}'
                                    : 'Message #${channel.name}')
                                : 'You do not have permission to send messages in this channel.',
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

              // Send Button (appears smoothly like Discord Mobile when typing/attaching)
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
