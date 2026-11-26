import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';
import 'discord_markdown.dart';

class MessageTile extends StatefulWidget {
  final DiscordMessage message;
  final bool compact;
  final bool showDateDivider;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final String currentBotUserId;
  final bool ecoMode;
  final bool canManageMessages;
  final void Function(DiscordMessage msg) onReply;
  final void Function(DiscordMessage msg) onEdit;
  final void Function(DiscordMessage msg) onEditEmbed;
  final void Function(DiscordMessage msg) onDelete;
  final void Function(DiscordMessage msg) onTogglePin;
  final void Function(DiscordMessage msg, DiscordEmoji emoji, bool me)
      onToggleReaction;
  final void Function(String userId) onOpenDm;

  const MessageTile({
    super.key,
    required this.message,
    required this.compact,
    this.showDateDivider = false,
    required this.palette,
    this.guild,
    required this.currentBotUserId,
    required this.ecoMode,
    required this.canManageMessages,
    required this.onReply,
    required this.onEdit,
    required this.onEditEmbed,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleReaction,
    required this.onOpenDm,
  });

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  double _dragOffset = 0;
  bool _triggeredHaptic = false;

  String _formatDiscordTime(DateTime dt) {
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天 $hh:$mm';
    }
    return '${dt.year}/${dt.month}/${dt.day} $hh:$mm';
  }

  void _showCustomEmojiPicker(BuildContext context) {
    final p = widget.palette;
    final guildEmojis = widget.guild?.emojis ?? const <DiscordEmoji>[];
    const commonUnicode = [
      '😀', '😂', '🥹', '😍', '🤔', '😎', '😭', '😡', '👍', '👎',
      '❤️', '🔥', '🎉', '✨', '💯', '👀', '🙏', '✅', '❌', '🚀',
    ];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '新增表情反應',
                  style: TextStyle(
                    color: p.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: commonUnicode.map((em) {
                    return InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        Navigator.of(ctx).pop();
                        final existing = widget.message.reactions.where(
                          (r) => r.emoji.name == em && r.emoji.id == null,
                        );
                        widget.onToggleReaction(
                          widget.message,
                          DiscordEmoji(name: em),
                          existing.isNotEmpty && existing.first.me,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Text(em, style: const TextStyle(fontSize: 24)),
                      ),
                    );
                  }).toList(),
                ),
                if (guildEmojis.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    '伺服器自訂表情',
                    style: TextStyle(
                      color: p.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: guildEmojis.take(40).map((ge) {
                      final url = ge.imageUrl(
                        size: 48,
                        allowAnimated: !widget.ecoMode,
                      );
                      return InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          final existing = widget.message.reactions.where(
                            (r) => r.emoji.id == ge.id,
                          );
                          widget.onToggleReaction(
                            widget.message,
                            ge,
                            existing.isNotEmpty && existing.first.me,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: url != null
                              ? Image.network(
                                  url,
                                  width: 28,
                                  height: 28,
                                  cacheWidth: 56,
                                )
                              : Text(':${ge.name}:'),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDiscordMessageSheet(BuildContext context) {
    final message = widget.message;
    final palette = widget.palette;
    final isOwn = message.author.id == widget.currentBotUserId;
    final canDm = !isOwn && !message.author.bot;
    const quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Circular Quick Reactions Row + Custom Emoji Picker Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ...quickEmojis.map((em) {
                        return InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () {
                            Navigator.of(ctx).pop();
                            final existing = message.reactions.where(
                              (r) => r.emoji.name == em && r.emoji.id == null,
                            );
                            final alreadyMe =
                                existing.isNotEmpty && existing.first.me;
                            widget.onToggleReaction(
                              message,
                              DiscordEmoji(name: em),
                              alreadyMe,
                            );
                          },
                          child: Container(
                            width: 42,
                            height: 42,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: palette.sidebarBg,
                              shape: BoxShape.circle,
                            ),
                            child:
                                Text(em, style: const TextStyle(fontSize: 19)),
                          ),
                        );
                      }),
                      InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          _showCustomEmojiPicker(context);
                        },
                        child: Container(
                          width: 42,
                          height: 42,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: palette.sidebarBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.add_reaction_outlined,
                              color: palette.textSecondary, size: 20),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Grouped Action Card
                  Container(
                    decoration: BoxDecoration(
                      color: palette.sidebarBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        _sheetTile(
                          ctx,
                          icon: Icons.reply_rounded,
                          label: '回覆',
                          onTap: () => widget.onReply(message),
                        ),
                        if (isOwn) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.edit_outlined,
                            label: '編輯訊息',
                            onTap: () => widget.onEdit(message),
                          ),
                        ],
                        if (isOwn && message.embeds.isNotEmpty) ...[
                          Divider(height: 1, color: palette.border),
                          ListTile(
                            dense: true,
                            leading: DbcEmbedIcon(
                              size: 19,
                              color: palette.textPrimary,
                            ),
                            title: Text(
                              '編輯 Embed',
                              style: TextStyle(
                                color: palette.textPrimary,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            onTap: () {
                              Navigator.of(ctx).pop();
                              widget.onEditEmbed(message);
                            },
                          ),
                        ],
                        if (widget.canManageMessages) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.push_pin_outlined,
                            label: message.pinned ? '取消釘選訊息' : '釘選訊息',
                            onTap: () => widget.onTogglePin(message),
                          ),
                        ],
                        if (canDm) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.chat_bubble_outline_rounded,
                            label: '傳送私訊',
                            onTap: () => widget.onOpenDm(message.author.id),
                          ),
                        ],
                        if (message.content.isNotEmpty) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.copy_rounded,
                            label: '複製文字',
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: message.content));
                            },
                          ),
                        ],
                        Divider(height: 1, color: palette.border),
                        _sheetTile(
                          ctx,
                          icon: Icons.tag_rounded,
                          label: '複製訊息 ID',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: message.id));
                          },
                        ),
                        if (isOwn || widget.canManageMessages) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.delete_outline_rounded,
                            label: '刪除訊息',
                            danger: true,
                            onTap: () => widget.onDelete(message),
                          ),
                        ],
                      ],
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

  Widget _sheetTile(
    BuildContext ctx, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? DiscordPalette.danger : widget.palette.textPrimary;
    return ListTile(
      dense: true,
      leading: Icon(icon, color: color, size: 20),
      title: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14.5,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: () {
        Navigator.of(ctx).pop();
        onTap();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    final palette = widget.palette;
    final compact = widget.compact && !widget.showDateDivider;
    final avatarPx = widget.ecoMode ? 64 : 96;
    final authorName = message.authorDisplayName(widget.guild);
    final roleColorInt = message.authorRoleColor(widget.guild);
    final authorColor = roleColorInt != null
        ? Color(0xFF000000 | roleColorInt)
        : palette.textPrimary;

    final replyProgress = (-_dragOffset / 48.0).clamp(0.0, 1.0);

    return RepaintBoundary(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Discord Date Divider between calendar days
          if (widget.showDateDivider)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(
                children: [
                  Expanded(child: Divider(color: palette.border, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      '${message.timestamp.year}年${message.timestamp.month}月${message.timestamp.day}日',
                      style: TextStyle(
                        color: palette.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: palette.border, height: 1)),
                ],
              ),
            ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _showDiscordMessageSheet(context),
            onHorizontalDragUpdate: (details) {
              if (details.delta.dx < 0 || _dragOffset < 0) {
                final next = (_dragOffset + details.delta.dx * 0.72)
                    .clamp(-62.0, 0.0);
                if (next <= -46 && !_triggeredHaptic) {
                  _triggeredHaptic = true;
                  HapticFeedback.lightImpact();
                } else if (next > -40) {
                  _triggeredHaptic = false;
                }
                setState(() => _dragOffset = next);
              }
            },
            onHorizontalDragCancel: () {
              if (_dragOffset != 0) {
                setState(() {
                  _dragOffset = 0;
                  _triggeredHaptic = false;
                });
              }
            },
            onHorizontalDragEnd: (_) {
              if (_dragOffset <= -46) {
                widget.onReply(message);
              }
              if (_dragOffset != 0) {
                setState(() {
                  _dragOffset = 0;
                  _triggeredHaptic = false;
                });
              }
            },
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                if (replyProgress > 0.05)
                  Positioned(
                    right: 14,
                    child: Opacity(
                      opacity: replyProgress,
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * replyProgress,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: replyProgress >= 0.95
                                ? DiscordPalette.blurple
                                : palette.elevatedBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.reply_rounded,
                            size: 17,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(_dragOffset, 0),
                  child: Padding(
                    padding:
                        EdgeInsets.fromLTRB(14, compact ? 2 : 10, 14, 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Authentic Discord Curved Reply Spine
                        if (message.referencedMessage != null)
                          Padding(
                            padding:
                                const EdgeInsets.only(left: 19, bottom: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 11,
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                          color: palette.border, width: 2),
                                      top: BorderSide(
                                          color: palette.border, width: 2),
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(6),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 8,
                                  backgroundImage: NetworkImage(
                                    message.referencedMessage!.author
                                        .avatarUrl(size: 32),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  message.referencedMessage!
                                      .authorDisplayName(widget.guild),
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    message.referencedMessage!.content.isEmpty
                                        ? '點擊查看附件'
                                        : message.referencedMessage!.content,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: palette.textMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!compact)
                              GestureDetector(
                                onTap: (!message.author.bot &&
                                        message.author.id !=
                                            widget.currentBotUserId)
                                    ? () => widget.onOpenDm(message.author.id)
                                    : null,
                                child: ClipOval(
                                  child: Image.network(
                                    message.author.avatarUrl(size: avatarPx),
                                    width: 38,
                                    height: 38,
                                    cacheWidth: avatarPx,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: 38,
                                      height: 38,
                                      color: DiscordPalette.blurple,
                                      alignment: Alignment.center,
                                      child: Text(
                                        authorName.isNotEmpty
                                            ? String.fromCharCode(
                                                    authorName.runes.first)
                                                .toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            else
                              const SizedBox(width: 38),

                            const SizedBox(width: 12),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!compact)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 2),
                                      child: Wrap(
                                        crossAxisAlignment:
                                            WrapCrossAlignment.center,
                                        spacing: 5,
                                        children: [
                                          Text(
                                            authorName,
                                            style: TextStyle(
                                              color: authorColor,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                            ),
                                          ),
                                          if (message.author.bot)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 4.5,
                                                      vertical: 1),
                                              decoration: BoxDecoration(
                                                color: DiscordPalette.blurple,
                                                borderRadius:
                                                    BorderRadius.circular(3.5),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  if (message.author
                                                      .isVerifiedBot) ...[
                                                    const Icon(
                                                      Icons.check_rounded,
                                                      size: 10,
                                                      color: Colors.white,
                                                    ),
                                                    const SizedBox(width: 1),
                                                  ],
                                                  const Text(
                                                    'APP',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 9.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          Text(
                                            _formatDiscordTime(
                                                message.timestamp),
                                            style: TextStyle(
                                              color: palette.textMuted,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          if (message.pinned)
                                            const Icon(
                                              Icons.push_pin_rounded,
                                              size: 12,
                                              color: DiscordPalette.yellow,
                                            ),
                                        ],
                                      ),
                                    ),

                                  if (message.content.isNotEmpty)
                                    DiscordMarkdownView(
                                      text: message.editedTimestamp != null
                                          ? '${message.content} *(已編輯)*'
                                          : message.content,
                                      palette: palette,
                                      guild: widget.guild,
                                      ecoMode: widget.ecoMode,
                                    ),

                                  if (message.attachments.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: message.attachments
                                            .map((att) => _AttachmentView(
                                                  attachment: att,
                                                  palette: palette,
                                                  ecoMode: widget.ecoMode,
                                                ))
                                            .toList(),
                                      ),
                                    ),

                                  if (message.embeds.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: message.embeds
                                            .map((emb) => _EmbedCard(
                                                  embed: emb,
                                                  palette: palette,
                                                  guild: widget.guild,
                                                  ecoMode: widget.ecoMode,
                                                ))
                                            .toList(),
                                      ),
                                    ),

                                  if (message.components.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children:
                                            message.components.map((btn) {
                                          return FilledButton(
                                            style: FilledButton.styleFrom(
                                              visualDensity:
                                                  VisualDensity.compact,
                                              backgroundColor: btn.style == 1
                                                  ? DiscordPalette.blurple
                                                  : const Color(0xFF4E5058),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                            onPressed: btn.url != null
                                                ? () {
                                                    final uri = Uri.tryParse(
                                                        btn.url!);
                                                    if (uri != null) {
                                                      launchUrl(
                                                        uri,
                                                        mode: LaunchMode
                                                            .externalApplication,
                                                      );
                                                    }
                                                  }
                                                : null,
                                            child: Text(
                                              btn.label ?? 'Button',
                                              style: const TextStyle(
                                                  fontSize: 13),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),

                                  if (message.reactions.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children:
                                            message.reactions.map((rxn) {
                                          final customUrl = rxn.emoji.imageUrl(
                                            size: 32,
                                            allowAnimated: !widget.ecoMode,
                                          );
                                          return InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onTap: () =>
                                                widget.onToggleReaction(
                                                    message,
                                                    rxn.emoji,
                                                    rxn.me),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 7,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: rxn.me
                                                    ? DiscordPalette.blurple
                                                        .withAlpha(55)
                                                    : palette.cardBg,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: rxn.me
                                                      ? DiscordPalette.blurple
                                                      : palette.border,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  if (customUrl != null)
                                                    Image.network(
                                                      customUrl,
                                                      width: 16,
                                                      height: 16,
                                                      cacheWidth: 32,
                                                    )
                                                  else
                                                    Text(rxn.emoji.name,
                                                        style:
                                                            const TextStyle(
                                                                fontSize: 13)),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${rxn.count}',
                                                    style: TextStyle(
                                                      color: rxn.me
                                                          ? Colors.white
                                                          : palette
                                                              .textSecondary,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentView extends StatelessWidget {
  final DiscordAttachment attachment;
  final DiscordPalette palette;
  final bool ecoMode;

  const _AttachmentView({
    required this.attachment,
    required this.palette,
    required this.ecoMode,
  });

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      final maxW = ecoMode ? 360 : 640;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: () {
            showDialog<void>(
              context: context,
              builder: (ctx) => Dialog.fullscreen(
                backgroundColor: Colors.black,
                child: Stack(
                  children: [
                    Center(
                      child: InteractiveViewer(
                        child: Image.network(attachment.url),
                      ),
                    ),
                    Positioned(
                      top: 40,
                      right: 16,
                      child: IconButton(
                        icon: const Icon(Icons.close,
                            color: Colors.white, size: 28),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 300),
              child: Image.network(
                attachment.previewUrl(maxWidth: maxW),
                cacheWidth: maxW,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fileCard(),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _fileCard(),
    );
  }

  Widget _fileCard() {
    return InkWell(
      onTap: () {
        final uri = Uri.tryParse(attachment.url);
        if (uri != null) {
          launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.insert_drive_file_outlined,
                color: DiscordPalette.blurple, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF00A8FC),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    attachment.formattedSize,
                    style: TextStyle(color: palette.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmbedCard extends StatelessWidget {
  final DiscordEmbed embed;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final bool ecoMode;

  const _EmbedCard({
    required this.embed,
    required this.palette,
    this.guild,
    required this.ecoMode,
  });

  @override
  Widget build(BuildContext context) {
    final accent = embed.color != null
        ? Color(0xFF000000 | embed.color!)
        : const Color(0xFF1E1F22);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxWidth: 430),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(4),
        border: Border(
          left: BorderSide(color: accent, width: 4),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (embed.authorName != null &&
                        embed.authorName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            if (embed.authorIconUrl != null &&
                                embed.authorIconUrl!.isNotEmpty) ...[
                              ClipOval(
                                child: Image.network(
                                  embed.authorIconUrl!,
                                  width: 20,
                                  height: 20,
                                  cacheWidth: 40,
                                  errorBuilder: (_, __, ___) =>
                                      const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Flexible(
                              child: Text(
                                embed.authorName!,
                                style: TextStyle(
                                  color: palette.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (embed.title != null && embed.title!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: embed.url != null
                              ? () {
                                  final uri = Uri.tryParse(embed.url!);
                                  if (uri != null) {
                                    launchUrl(uri,
                                        mode: LaunchMode.externalApplication);
                                  }
                                }
                              : null,
                          child: Text(
                            embed.title!,
                            style: TextStyle(
                              color: embed.url != null
                                  ? const Color(0xFF00A8FC)
                                  : palette.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                    if (embed.description != null &&
                        embed.description!.isNotEmpty)
                      DiscordMarkdownView(
                        text: embed.description!,
                        palette: palette,
                        guild: guild,
                        ecoMode: ecoMode,
                        fontSize: 13.5,
                      ),
                  ],
                ),
              ),
              if (embed.thumbnailUrl != null && embed.thumbnailUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      embed.thumbnailUrl!,
                      width: 68,
                      height: 68,
                      cacheWidth: 136,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
          if (embed.fields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: embed.fields.map((f) {
                  return SizedBox(
                    width: f.inline ? 135 : double.infinity,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          f.name,
                          style: TextStyle(
                            color: palette.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        DiscordMarkdownView(
                          text: f.value,
                          palette: palette,
                          guild: guild,
                          ecoMode: ecoMode,
                          fontSize: 12.5,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          if (embed.imageUrl != null && embed.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: Image.network(
                    embed.imageUrl!,
                    cacheWidth: ecoMode ? 360 : 600,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          if (embed.footerText != null && embed.footerText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (embed.footerIconUrl != null &&
                      embed.footerIconUrl!.isNotEmpty) ...[
                    ClipOval(
                      child: Image.network(
                        embed.footerIconUrl!,
                        width: 16,
                        height: 16,
                        cacheWidth: 32,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      embed.footerText!,
                      style: TextStyle(color: palette.textMuted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
