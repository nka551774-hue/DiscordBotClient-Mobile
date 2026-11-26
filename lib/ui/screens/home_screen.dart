import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../../services/discord_gateway_service.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/embed_composer_sheet.dart';
import '../widgets/guild_tools_sheet.dart';
import '../widgets/message_tile.dart';
import '../widgets/settings_sheet.dart';

class HomeScreen extends StatefulWidget {
  final BotClientController controller;

  const HomeScreen({super.key, required this.controller});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _composerCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _imagePicker = ImagePicker();

  DiscordMessage? _replyTarget;
  DiscordMessage? _editingTarget;
  Uint8List? _pendingAttachmentBytes;
  String? _pendingAttachmentName;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
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

  Future<void> _pickImageAttachment() async {
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
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選取圖片失敗：$e')),
      );
    }
  }

  Future<void> _sendComposerMessage({
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
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('編輯失敗：$e')),
        );
      }
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('發送失敗：$e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showPinnedMessagesSheet(DiscordPalette p) async {
    final ch = widget.controller.selectedChannel;
    final rest = widget.controller.rest;
    if (ch == null || rest == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          builder: (_, sCtrl) {
            return FutureBuilder<List<DiscordMessage>>(
              future: rest.getPinnedMessages(ch.id),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final pins = snap.data ?? const [];
                if (pins.isEmpty) {
                  return Center(
                    child: Text('此頻道尚無釘選訊息',
                        style: TextStyle(color: p.textMuted)),
                  );
                }
                return ListView.separated(
                  controller: sCtrl,
                  padding: const EdgeInsets.all(14),
                  itemCount: pins.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, i) {
                    final m = pins[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage:
                            NetworkImage(m.author.avatarUrl(size: 64)),
                      ),
                      title: Text(m.author.displayName,
                          style: TextStyle(
                              color: p.textPrimary,
                              fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        m.content.isEmpty ? '[Embed / 附件]' : m.content,
                        style: TextStyle(color: p.textSecondary),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _promptOpenDmById(DiscordPalette p) async {
    final idCtrl = TextEditingController();
    final userId = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: p.cardBg,
        title: const Text('開啟私訊 (Direct Message)'),
        content: TextField(
          controller: idCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '輸入目標使用者的 Discord User ID',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(idCtrl.text.trim()),
            child: const Text('開啟'),
          ),
        ],
      ),
    );
    if (userId != null && userId.isNotEmpty) {
      try {
        await widget.controller.openDmWithUser(userId);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法開啟私訊：$e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    final p = DiscordPalette(oled: ctrl.ecoSettings.oledBlackMode);
    final isWide = MediaQuery.of(context).size.width >= 760;

    final navigationPanel = SizedBox(
      width: 312,
      child: _NavigationSidePanel(
        controller: ctrl,
        palette: p,
        onChannelChosen: () {
          if (!isWide) {
            _scaffoldKey.currentState?.closeDrawer();
          }
        },
        onNewDmRequested: () => _promptOpenDmById(p),
        onOpenSettings: () {
          if (!isWide) _scaffoldKey.currentState?.closeDrawer();
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                SettingsAndEcoSheet(controller: ctrl, palette: p),
          );
        },
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: p.chatBg,
      drawer: isWide ? null : Drawer(width: 312, child: navigationPanel),
      body: SafeArea(
        child: Row(
          children: [
            if (isWide) ...[
              navigationPanel,
              VerticalDivider(width: 1, color: p.border),
            ],
            Expanded(
              child: _buildChatArea(ctrl, p, isWide: isWide),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatArea(
    BotClientController ctrl,
    DiscordPalette p, {
    required bool isWide,
  }) {
    final channel = ctrl.selectedChannel;
    final guild = ctrl.selectedGuild;
    final perms = ctrl.currentChannelPermissions();
    final canManageMessages =
        DiscordPermissions.has(perms, DiscordPermissions.manageMessages);
    final canSend = ctrl.canSendInSelectedChannel();

    return Column(
      children: [
        // Top Channel Bar
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: p.chatBg,
            border: Border(bottom: BorderSide(color: p.border, width: 0.8)),
          ),
          child: Row(
            children: [
              if (!isWide)
                IconButton(
                  icon: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.menu_rounded),
                      if (ctrl.unreadChannelIds.isNotEmpty)
                        Positioned(
                          right: -2,
                          top: -2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: DiscordPalette.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              Icon(
                channel == null
                    ? Icons.forum_outlined
                    : (channel.isDm
                        ? Icons.alternate_email_rounded
                        : (channel.isVoice
                            ? Icons.volume_up_rounded
                            : Icons.tag_rounded)),
                size: 20,
                color: p.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel?.displayTitle ?? '選擇頻道開始對話',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (channel?.topic != null && channel!.topic!.isNotEmpty)
                      Text(
                        channel.topic!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.textMuted, fontSize: 11),
                      ),
                  ],
                ),
              ),

              // Optional Live Performance & Gateway HUD
              if (ctrl.ecoSettings.showPerformanceHud)
                ValueListenableBuilder<int?>(
                  valueListenable: ctrl.pingMsNotifier,
                  builder: (_, ms, __) {
                    return Container(
                      margin: const EdgeInsets.only(right: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: p.cardBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: p.border),
                      ),
                      child: Text(
                        ms != null ? '${ms}ms' : ctrl.gatewayState.name,
                        style: const TextStyle(
                          color: DiscordPalette.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  },
                ),

              if (channel != null)
                IconButton(
                  tooltip: '釘選訊息',
                  icon: Icon(Icons.push_pin_outlined,
                      size: 20, color: p.textSecondary),
                  onPressed: () => _showPinnedMessagesSheet(p),
                ),
              IconButton(
                tooltip: '伺服器與機器人工具',
                icon: Icon(Icons.tune_rounded,
                    size: 20, color: p.textSecondary),
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) =>
                        GuildToolsSheet(controller: ctrl, palette: p),
                  );
                },
              ),
            ],
          ),
        ),

        // Disallowed Privileged Intents Auto-Fallback Notice
        if (ctrl.disallowedIntentsBanner)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            color: DiscordPalette.yellow.withAlpha(38),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: DiscordPalette.yellow),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://discord.com/developers/applications'),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: const Text(
                      '已自動以基礎權限連線。若訊息文字空白，請至 Developer Portal 開啟 Message Content Intent。',
                      style: TextStyle(fontSize: 12, color: Color(0xFFFFE28A)),
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: ctrl.dismissIntentsBanner,
                ),
              ],
            ),
          ),

        // 120fps Virtualized Message List
        Expanded(
          child: channel == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.smart_toy_outlined,
                          size: 48, color: p.textMuted),
                      const SizedBox(height: 10),
                      Text(
                        '從左側選單選擇伺服器頻道或開啟私訊',
                        style: TextStyle(color: p.textMuted, fontSize: 14),
                      ),
                    ],
                  ),
                )
              : ValueListenableBuilder<bool>(
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
                                  padding: const EdgeInsets.all(32),
                                  child: Center(
                                    child: Text(
                                      '尚無訊息，立即以機器人身分發送第一則訊息！',
                                      style: TextStyle(
                                          color: p.textMuted, fontSize: 13),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollCtrl,
                          reverse: true,
                          cacheExtent:
                              ctrl.ecoSettings.ecoPowerSaving ? 350 : 750,
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
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('刪除失敗：$e')),
                                  );
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
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('釘選操作失敗：$e')),
                                  );
                                }
                              },
                              onToggleReaction: (m, emoji, me) async {
                                try {
                                  await ctrl.toggleReaction(m, emoji, me);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('反應失敗：$e')),
                                  );
                                }
                              },
                              onOpenDm: (uid) async {
                                try {
                                  await ctrl.openDmWithUser(uid);
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('開啟私訊失敗：$e')),
                                  );
                                }
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                ),
        ),

        // Typing Indicator Banner
        ValueListenableBuilder<String?>(
          valueListenable: ctrl.typingBannerNotifier,
          builder: (_, text, __) {
            if (text == null) return const SizedBox.shrink();
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
              color: p.chatBg,
              child: Text(
                text,
                style: TextStyle(color: p.textSecondary, fontSize: 11.5),
              ),
            );
          },
        ),

        // Reply / Edit / Attachment Status Bar
        if (_replyTarget != null ||
            _editingTarget != null ||
            _pendingAttachmentName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: p.sidebarBg,
              border: Border(top: BorderSide(color: p.border)),
            ),
            child: Row(
              children: [
                Icon(
                  _editingTarget != null
                      ? Icons.edit_rounded
                      : (_pendingAttachmentName != null
                          ? Icons.attach_file_rounded
                          : Icons.reply_rounded),
                  size: 16,
                  color: DiscordPalette.blurple,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _editingTarget != null
                        ? '正在編輯訊息'
                        : (_pendingAttachmentName != null
                            ? '已附加圖片：$_pendingAttachmentName'
                            : '回覆 @${_replyTarget!.author.displayName}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.textSecondary, fontSize: 12.5),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close, size: 16, color: p.textMuted),
                  onPressed: () => setState(() {
                    _replyTarget = null;
                    _editingTarget = null;
                    _pendingAttachmentBytes = null;
                    _pendingAttachmentName = null;
                  }),
                ),
              ],
            ),
          ),

        // Composer Bar
        if (channel != null)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
            decoration: BoxDecoration(
              color: p.chatBg,
              border: Border(top: BorderSide(color: p.border, width: 0.7)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: '上傳圖片',
                  onPressed: canSend ? _pickImageAttachment : null,
                  icon: Icon(Icons.add_photo_alternate_outlined,
                      color: p.textSecondary),
                ),
                IconButton(
                  tooltip: '發送機器人 Embed',
                  onPressed: canSend
                      ? () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            builder: (_) => EmbedComposerSheet(
                              palette: p,
                              onSend: (emb, extraText) => _sendComposerMessage(
                                embeds: [emb],
                                overrideContent: extraText,
                              ),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.auto_awesome_mosaic_outlined,
                      color: DiscordPalette.blurple),
                ),
                Expanded(
                  child: TextField(
                    controller: _composerCtrl,
                    enabled: canSend,
                    minLines: 1,
                    maxLines: 5,
                    onChanged: (_) => ctrl.notifyUserTyping(),
                    style: TextStyle(color: p.textPrimary, fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: canSend
                          ? '以 ${ctrl.activeAccount?.displayName ?? "Bot"} 傳送訊息...'
                          : '機器人在此頻道無發送訊息權限',
                      hintStyle: TextStyle(color: p.textMuted, fontSize: 13.5),
                      filled: true,
                      fillColor: p.inputBg,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: DiscordPalette.blurple,
                  ),
                  onPressed: (!canSend || _sending)
                      ? null
                      : () => _sendComposerMessage(),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send_rounded,
                          size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NavigationSidePanel extends StatelessWidget {
  final BotClientController controller;
  final DiscordPalette palette;
  final VoidCallback onChannelChosen;
  final VoidCallback onNewDmRequested;
  final VoidCallback onOpenSettings;

  const _NavigationSidePanel({
    required this.controller,
    required this.palette,
    required this.onChannelChosen,
    required this.onNewDmRequested,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final guilds = controller.guilds;
    final selectedGuild = controller.selectedGuild;
    final isDmMode = controller.selectedGuildId == null;
    final iconSize = controller.ecoSettings.avatarSize;

    return Container(
      color: palette.sidebarBg,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // 1. Leftmost Server Icons Rail (72px)
                Container(
                  width: 72,
                  color: palette.railBg,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    children: [
                      // DM Inbox Button
                      _RailAvatarItem(
                        selected: isDmMode,
                        palette: palette,
                        onTap: () => controller.selectDmMode(),
                        child: const Icon(Icons.chat_bubble_rounded,
                            color: Colors.white, size: 22),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 6),
                        child: Divider(height: 1, color: palette.border),
                      ),
                      // Guild Icons
                      ...guilds.map((g) {
                        final selected = controller.selectedGuildId == g.id;
                        final iconUrl = g.iconUrl(size: iconSize);
                        return _RailAvatarItem(
                          selected: selected,
                          palette: palette,
                          onTap: () => controller.selectGuild(g.id),
                          child: iconUrl != null
                              ? Image.network(
                                  iconUrl,
                                  width: 46,
                                  height: 46,
                                  cacheWidth: iconSize,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    g.initials,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : Text(
                                  g.initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                        );
                      }),
                    ],
                  ),
                ),

                // 2. Channels / DMs Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          border: Border(
                              bottom:
                                  BorderSide(color: palette.border, width: 0.8)),
                        ),
                        alignment: Alignment.centerLeft,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                isDmMode
                                    ? '私人訊息 (DM)'
                                    : (selectedGuild?.name ?? '伺服器'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                            if (isDmMode)
                              IconButton(
                                tooltip: '透過 User ID 開啟私訊',
                                visualDensity: VisualDensity.compact,
                                onPressed: onNewDmRequested,
                                icon: Icon(Icons.person_add_alt_1_rounded,
                                    size: 18, color: palette.textSecondary),
                              ),
                          ],
                        ),
                      ),

                      // Channel or DM List
                      Expanded(
                        child: isDmMode
                            ? _buildDmList()
                            : (selectedGuild == null
                                ? const SizedBox.shrink()
                                : _buildGuildChannelList(selectedGuild)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Bot Status & Settings Footer Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: palette.railBg,
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: onOpenSettings,
              child: Row(
                children: [
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundImage: controller.activeAccount != null
                            ? NetworkImage(controller.activeAccount!
                                .avatarUrl(size: 64))
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: _gatewayDotColor(controller.gatewayState),
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: palette.railBg, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                controller.activeAccount?.displayName ?? 'Bot',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (controller.ecoSettings.ecoPowerSaving) ...[
                              const SizedBox(width: 5),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: DiscordPalette.green.withAlpha(40),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'ECO',
                                  style: TextStyle(
                                    color: DiscordPalette.green,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _gatewayLabel(controller.gatewayState),
                          style:
                              TextStyle(color: palette.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.settings_outlined,
                      size: 20, color: palette.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _gatewayDotColor(GatewayConnectionState st) {
    switch (st) {
      case GatewayConnectionState.connected:
        return DiscordPalette.green;
      case GatewayConnectionState.connecting:
        return DiscordPalette.yellow;
      case GatewayConnectionState.suspendedEco:
        return DiscordPalette.blurple;
      case GatewayConnectionState.disconnected:
        return DiscordPalette.red;
    }
  }

  String _gatewayLabel(GatewayConnectionState st) {
    switch (st) {
      case GatewayConnectionState.connected:
        return 'Gateway 已連線';
      case GatewayConnectionState.connecting:
        return '正在連線中...';
      case GatewayConnectionState.suspendedEco:
        return 'Eco 背景省電休眠';
      case GatewayConnectionState.disconnected:
        return '未連線';
    }
  }

  Widget _buildDmList() {
    final dms = controller.dmChannels;
    if (dms.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '尚無私訊紀錄\n當有人私訊機器人時會自動顯示於此，或點擊右上角輸入 User ID 開啟對話。',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: palette.textMuted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onNewDmRequested,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('輸入 User ID 私訊'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      itemCount: dms.length,
      itemBuilder: (_, idx) {
        final ch = dms[idx];
        final selected = controller.selectedChannelId == ch.id;
        final unread = controller.unreadChannelIds.contains(ch.id);
        final recipient = ch.dmRecipient;

        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          selected: selected,
          selectedTileColor: DiscordPalette.blurple.withAlpha(45),
          leading: CircleAvatar(
            radius: 14,
            backgroundImage: recipient != null
                ? NetworkImage(recipient.avatarUrl(size: 64))
                : null,
            child: recipient == null
                ? const Icon(Icons.person, size: 15)
                : null,
          ),
          title: Text(
            ch.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected || unread
                  ? palette.textPrimary
                  : palette.textSecondary,
              fontWeight: selected || unread ? FontWeight.w700 : FontWeight.w500,
              fontSize: 13.5,
            ),
          ),
          onTap: () {
            controller.selectChannel(ch.id);
            onChannelChosen();
          },
        );
      },
    );
  }

  Widget _buildGuildChannelList(DiscordGuild guild) {
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
      items.add(_buildChannelTile(ch));
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
            padding: const EdgeInsets.fromLTRB(6, 12, 8, 4),
            child: Row(
              children: [
                Icon(
                  collapsed
                      ? Icons.keyboard_arrow_right_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 15,
                  color: palette.textMuted,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    cat.name.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
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
          items.add(_buildChannelTile(ch));
        }
      } else {
        // Still show currently selected channel even if category is collapsed
        for (final ch in children) {
          if (ch.id == controller.selectedChannelId) {
            items.add(_buildChannelTile(ch));
          }
        }
      }
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      children: items,
    );
  }

  Widget _buildChannelTile(DiscordChannel ch) {
    final selected = controller.selectedChannelId == ch.id;
    final unread = controller.unreadChannelIds.contains(ch.id);

    IconData icon = Icons.tag_rounded;
    if (ch.type == 2) icon = Icons.volume_up_rounded;
    if (ch.type == 5) icon = Icons.campaign_rounded;
    if (ch.type == 11 || ch.type == 12) icon = Icons.subdirectory_arrow_right;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: InkWell(
        borderRadius: BorderRadius.circular(7),
        onTap: () {
          controller.selectChannel(ch.id);
          onChannelChosen();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? DiscordPalette.blurple.withAlpha(48)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 17,
                color: selected ? Colors.white : palette.textMuted,
              ),
              const SizedBox(width: 8),
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
                    fontSize: 13.8,
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

class _RailAvatarItem extends StatelessWidget {
  final bool selected;
  final DiscordPalette palette;
  final VoidCallback onTap;
  final Widget child;

  const _RailAvatarItem({
    required this.selected,
    required this.palette,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 4,
              height: selected ? 34 : 0,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.horizontal(right: Radius.circular(4)),
              ),
            ),
            const Spacer(),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 46,
              height: 46,
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? DiscordPalette.blurple : palette.cardBg,
                borderRadius: BorderRadius.circular(selected ? 15 : 23),
              ),
              child: child,
            ),
            const Spacer(),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
