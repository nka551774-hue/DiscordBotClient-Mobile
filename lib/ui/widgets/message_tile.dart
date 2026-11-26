import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';
import 'discord_markdown.dart';
import 'vencord_sheets.dart';

class MessageTile extends StatefulWidget {
  final BotClientController controller;
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
  final void Function(DiscordUser user, {DiscordMember? member})
      onOpenUserProfile;
  final void Function(String userId)? onTapUserMention;
  final VoidCallback? onNavigateToDm;

  const MessageTile({
    super.key,
    required this.controller,
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
    required this.onOpenUserProfile,
    this.onTapUserMention,
    this.onNavigateToDm,
  });

  @override
  State<MessageTile> createState() => _MessageTileState();
}

class _MessageTileState extends State<MessageTile> {
  double _dragOffset = 0;
  bool _triggeredHaptic = false;

  void _openAuthorProfile() {
    final msg = widget.message;
    final cached = widget.guild?.cachedMembers[msg.author.id];
    final member = cached ??
        ((msg.memberRoleIds.isNotEmpty || msg.memberNick != null)
            ? DiscordMember(
                user: msg.author,
                nick: msg.memberNick,
                roleIds: msg.memberRoleIds,
              )
            : null);
    widget.onOpenUserProfile(msg.author, member: member);
  }

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
    showDiscordEmojiPickerSheet(
      context,
      controller: widget.controller,
      palette: widget.palette,
      guild: widget.guild,
      onSelectEmoji: (em) {
        final existing = widget.message.reactions.where(
          (r) => r.emoji.apiIdentifier == em.apiIdentifier,
        );
        widget.onToggleReaction(
          widget.message,
          em,
          existing.isNotEmpty && existing.first.me,
        );
      },
    );
  }

  void _showDiscordMessageSheet(BuildContext context) {
    final vc = widget.controller.vencord;
    final message = widget.message;
    final palette = widget.palette;
    final isOwn = message.author.id == widget.currentBotUserId;
    final canDm = !isOwn && !message.author.bot;
    final showEditBtn =
        vc.getSetting<bool>('BotClient', 'embedEditMessageButton', true);
    final isAdvancedEditor = vc.getSetting<String>(
            'BotClient', 'messageEditor', 'advanced') ==
        'advanced';
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

                  // Circular Quick Reactions Row + Unified Application/Guild Emoji Picker Button
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
                        Divider(height: 1, color: palette.border),
                        _sheetTile(
                          ctx,
                          icon: Icons.person_outline_rounded,
                          label: '檢視個人資料',
                          onTap: _openAuthorProfile,
                        ),
                        if (isOwn && !message.isDeleted) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.edit_outlined,
                            label: '編輯訊息',
                            onTap: () => widget.onEdit(message),
                          ),
                        ],
                        if (isOwn &&
                            !message.isDeleted &&
                            showEditBtn &&
                            (isAdvancedEditor ||
                                message.embeds.isNotEmpty ||
                                message.isComponentsV2)) ...[
                          Divider(height: 1, color: palette.border),
                          ListTile(
                            dense: true,
                            leading: DbcEmbedIcon(
                              size: 19,
                              color: palette.textPrimary,
                            ),
                            title: Text(
                              isAdvancedEditor
                                  ? '進階訊息 / Embed 編輯器'
                                  : '編輯 Embed',
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
                        if (vc.isPluginEnabled('Translate') &&
                            (message.content.isNotEmpty ||
                                message.embeds.isNotEmpty)) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.translate_rounded,
                            label: message.translatedText != null
                                ? '隱藏翻譯結果'
                                : '翻譯訊息 (Translate)',
                            onTap: () async {
                              try {
                                await widget.controller
                                    .translateMessageInline(message);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('翻譯失敗：$e')),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                        if (widget.canManageMessages && !message.isDeleted) ...[
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
                        if (vc.isPluginEnabled('ViewRaw')) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.code_rounded,
                            label: '檢視原始資料 (View Raw)',
                            onTap: () {
                              showVencordRawModal(
                                context,
                                palette: palette,
                                title: 'Message',
                                data: message.rawJson ??
                                    {
                                      'id': message.id,
                                      'channel_id': message.channelId,
                                      'content': message.content,
                                    },
                                rawContent: message.content,
                                sortKeys: vc.getSetting<bool>(
                                    'ViewRaw', 'sortKeys', true),
                              );
                            },
                          ),
                        ],
                        if (vc.isPluginEnabled('MessageLogger') &&
                            (message.isDeleted ||
                                message.editHistory.isNotEmpty)) ...[
                          Divider(height: 1, color: palette.border),
                          _sheetTile(
                            ctx,
                            icon: Icons.history_toggle_off_rounded,
                            label: '清除訊息紀錄 (MessageLogger)',
                            onTap: () => widget.controller
                                .clearLoggedMessageHistory(message),
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
                        if ((isOwn || widget.canManageMessages) &&
                            !message.isDeleted) ...[
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
    final vc = widget.controller.vencord;
    final message = widget.message;
    final palette = widget.palette;
    final compact = widget.compact && !widget.showDateDivider;
    final avatarPx = widget.ecoMode ? 64 : 96;
    final authorName = message.authorDisplayName(widget.guild);
    final roleColorInt = message.authorRoleColor(widget.guild);
    final authorColor = roleColorInt != null
        ? Color(0xFF000000 | roleColorInt)
        : palette.textPrimary;

    final revealSpoilers = vc.isPluginEnabled('RevealAllSpoilers');
    final alwaysAnim = vc.isPluginEnabled('AlwaysAnimate');
    final roleColorMentions = vc.isPluginEnabled('RoleColorEverywhere') &&
        vc.getSetting<bool>('RoleColorEverywhere', 'chatMentions', true);
    final logEnabled = vc.isPluginEnabled('MessageLogger');
    final showInlineEdits = message.editHistory.isNotEmpty &&
        logEnabled &&
        vc.getSetting<bool>('MessageLogger', 'inlineEdits', true);
    final deleteOverlay = message.isDeleted &&
        logEnabled &&
        vc.getSetting<String>('MessageLogger', 'deleteStyle', 'text') ==
            'overlay';

    String? latencyBadge;
    if (vc.isPluginEnabled('MessageLatency')) {
      final deltaMs = message.timestamp
          .difference(snowflakeCreatedAt(message.id))
          .inMilliseconds
          .abs();
      final thresholdSec =
          vc.getSetting<int>('MessageLatency', 'latencyThresholdSec', 2);
      if (deltaMs >= thresholdSec * 1000) {
        latencyBadge = '${(deltaMs / 1000).toStringAsFixed(1)}s';
      }
    }

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
                                GestureDetector(
                                  onTap: () => widget.onOpenUserProfile(
                                    message.referencedMessage!.author,
                                    member: widget.guild?.cachedMembers[
                                        message.referencedMessage!.author.id],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
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
                                    ],
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
                                onTap: _openAuthorProfile,
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
                                          GestureDetector(
                                            onTap: _openAuthorProfile,
                                            child: Text(
                                              authorName,
                                              style: TextStyle(
                                                color: authorColor,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
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
                                          if (latencyBadge != null)
                                            Text(
                                              '($latencyBadge)',
                                              style: TextStyle(
                                                color: palette.textMuted,
                                                fontSize: 11,
                                              ),
                                            ),
                                          if (message.isSilentMessage)
                                            Icon(
                                              Icons.notifications_off_outlined,
                                              size: 12,
                                              color: palette.textMuted,
                                            ),
                                          if (message.isDeleted)
                                            const Text(
                                              '(已刪除)',
                                              style: TextStyle(
                                                color: DiscordPalette.danger,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
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

                                  if (showInlineEdits)
                                    ...message.editHistory.map((edit) {
                                      final eh = edit.timestamp.hour
                                          .toString()
                                          .padLeft(2, '0');
                                      final em = edit.timestamp.minute
                                          .toString()
                                          .padLeft(2, '0');
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Opacity(
                                          opacity: 0.56,
                                          child: Text(
                                            '${edit.content}  (編輯前 $eh:$em)',
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                  if (message.content.isNotEmpty)
                                    Container(
                                      padding: deleteOverlay
                                          ? const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 4)
                                          : EdgeInsets.zero,
                                      decoration: deleteOverlay
                                          ? BoxDecoration(
                                              color: DiscordPalette.danger
                                                  .withAlpha(36),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: DiscordPalette.danger
                                                    .withAlpha(90),
                                                width: 0.8,
                                              ),
                                            )
                                          : null,
                                      child: DiscordMarkdownView(
                                        text: message.isDeleted
                                            ? '${message.content} *(已刪除)*'
                                            : (message.editedTimestamp != null
                                                ? '${message.content} *(已編輯)*'
                                                : message.content),
                                        palette: palette,
                                        guild: widget.guild,
                                        ecoMode: widget.ecoMode,
                                        revealAllSpoilers: revealSpoilers,
                                        alwaysAnimate: alwaysAnim,
                                        roleColorMentions: roleColorMentions,
                                        overrideTextColor:
                                            (message.isDeleted && !deleteOverlay)
                                                ? DiscordPalette.danger
                                                : null,
                                        onTapUserMention:
                                            widget.onTapUserMention,
                                      ),
                                    ),

                                  if (message.translatedText != null &&
                                      message.translatedText!.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(top: 6),
                                      padding: const EdgeInsets.fromLTRB(
                                          10, 7, 8, 7),
                                      decoration: BoxDecoration(
                                        color: palette.cardBg,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border(
                                          left: BorderSide(
                                              color: palette.brandColor,
                                              width: 3),
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.translate_rounded,
                                              size: 14,
                                              color: palette.brandColor),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: SelectableText(
                                              message.translatedText!,
                                              style: TextStyle(
                                                color: palette.textPrimary,
                                                fontSize: 13.5,
                                                height: 1.35,
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => widget.controller
                                                .translateMessageInline(
                                                    message),
                                            child: Icon(Icons.close_rounded,
                                                size: 15,
                                                color: palette.textMuted),
                                          ),
                                        ],
                                      ),
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
                                            allowAnimated:
                                                !widget.ecoMode || alwaysAnim,
                                          );
                                          return InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onTap: () =>
                                                widget.onToggleReaction(
                                                    message,
                                                    rxn.emoji,
                                                    rxn.me),
                                            onLongPress: vc.isPluginEnabled(
                                                    'WhoReacted')
                                                ? () {
                                                    HapticFeedback
                                                        .selectionClick();
                                                    showWhoReactedSheet(
                                                      context,
                                                      controller:
                                                          widget.controller,
                                                      palette: palette,
                                                      message: message,
                                                      emoji: rxn.emoji,
                                                      onNavigateToDm:
                                                          widget.onNavigateToDm,
                                                    );
                                                  }
                                                : null,
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
