import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../../state/bot_client_controller.dart';
import '../theme/app_theme.dart';
import 'discord_icons.dart';
import 'discord_markdown.dart';
import 'media_viewer.dart';
import 'message_components.dart';
import 'vencord_sheets.dart';
import '../../l10n/strings.dart';

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
  final void Function(DiscordMessage msg)? onMention;

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
    this.onMention,
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

  void _openMedia(List<MediaViewerItem> items, int index) {
    showDiscordMediaViewer(
      context,
      items: items,
      initialIndex: index,
      authorName: widget.message.authorDisplayName(widget.guild),
      authorAvatarUrl: widget.message.author.avatarUrl(size: 64),
      timestamp: widget.message.timestamp,
    );
  }

  // Swipe-to-reply via raw pointer events: unlike a drag recognizer this never
  // wins the gesture arena, so right-swipes still reach the page-back gesture.
  Offset? _swipeStart;
  bool _swipeActive = false;

  void _onSwipeMove(PointerMoveEvent e) {
    final start = _swipeStart;
    if (start == null) return;
    final d = e.position - start;
    if (!_swipeActive) {
      if (d.dx < -14 && d.dx.abs() > d.dy.abs() * 1.6) {
        _swipeActive = true;
      } else if (d.dx > 8 || d.dy.abs() > 14) {
        _swipeStart = null; // not a left swipe: let other gestures have it
        return;
      } else {
        return;
      }
    }
    final next = (d.dx * 0.72).clamp(-62.0, 0.0);
    if (next <= -46 && !_triggeredHaptic) {
      _triggeredHaptic = true;
      HapticFeedback.lightImpact();
    } else if (next > -40) {
      _triggeredHaptic = false;
    }
    setState(() => _dragOffset = next);
  }

  void _onSwipeEnd() {
    if (_swipeActive && _dragOffset <= -46) {
      widget.onReply(widget.message);
    }
    _swipeStart = null;
    _swipeActive = false;
    if (_dragOffset != 0) {
      setState(() {
        _dragOffset = 0;
        _triggeredHaptic = false;
      });
    }
  }

  String _formatDiscordTime(DateTime dt) {
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return trf('今天 {0}:{1}', [hh, mm]);
    }
    final y = now.subtract(const Duration(days: 1));
    if (dt.year == y.year && dt.month == y.month && dt.day == y.day) {
      return trf('昨天 {0}:{1}', [hh, mm]);
    }
    return '${dt.year}/${dt.month}/${dt.day} $hh:$mm';
  }

  void _showCustomEmojiPicker(BuildContext context) {
    showDiscordEmojiPickerSheet(
      context,
      controller: widget.controller,
      palette: widget.palette,
      guild: widget.guild,
      forReaction: true,
      onSelectEmoji: (em) {
        final existing = widget.message.reactions.where(
          (r) => (em.id != null && em.id!.isNotEmpty)
              ? r.emoji.id == em.id
              : (r.emoji.id == null && r.emoji.name == em.name),
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
    final showEditBtn =
        vc.getSetting<bool>('BotClient', 'embedEditMessageButton', true);
    final isAdvancedEditor = vc.getSetting<String>(
            'BotClient', 'messageEditor', 'advanced') ==
        'advanced';
    const quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🔥'];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
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

                  // Official mobile action groups (rounded cards, same order as Discord)
                  ..._sheetGroups([
                    [
                      if (isOwn && !message.isDeleted)
                        _sheetTile(
                          ctx,
                          icon: Icons.edit_outlined,
                          label: tr('編輯訊息'),
                          onTap: () => widget.onEdit(message),
                        ),
                      _sheetTile(
                        ctx,
                        icon: Icons.reply_rounded,
                        label: tr('回覆'),
                        onTap: () => widget.onReply(message),
                      ),
                      if (widget.onMention != null && !isOwn)
                        _sheetTile(
                          ctx,
                          icon: Icons.alternate_email_rounded,
                          label: tr('提及'),
                          onTap: () => widget.onMention!(message),
                        ),
                    ],
                    [
                      _sheetTile(
                        ctx,
                        icon: Icons.mark_chat_unread_outlined,
                        label: tr('標示為未讀'),
                        onTap: () => widget.controller.markUnreadFrom(message),
                      ),
                      if (message.content.isNotEmpty)
                        _sheetTile(
                          ctx,
                          icon: Icons.copy_rounded,
                          label: tr('複製文字'),
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: message.content));
                          },
                        ),
                      if (widget.canManageMessages && !message.isDeleted)
                        _sheetTile(
                          ctx,
                          icon: Icons.push_pin_outlined,
                          label: message.pinned ? tr('取消釘選訊息') : tr('釘選訊息'),
                          onTap: () => widget.onTogglePin(message),
                        ),
                      _sheetTile(
                        ctx,
                        icon: Icons.link_rounded,
                        label: tr('複製訊息連結'),
                        onTap: () {
                          final gid =
                              widget.guild?.id ?? message.guildId ?? '@me';
                          Clipboard.setData(ClipboardData(
                            text:
                                'https://discord.com/channels/$gid/${message.channelId}/${message.id}',
                          ));
                        },
                      ),
                    ],
                    [
                      if (isOwn &&
                          !message.isDeleted &&
                          showEditBtn &&
                          (isAdvancedEditor ||
                              message.embeds.isNotEmpty ||
                              message.isComponentsV2))
                        ListTile(
                          dense: true,
                          leading: DbcEmbedIcon(
                            size: 19,
                            color: palette.textPrimary,
                          ),
                          title: Text(
                            isAdvancedEditor ? tr('進階訊息 / Embed 編輯器') : tr('編輯 Embed'),
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
                      if (vc.isPluginEnabled('Translate') &&
                          (message.content.isNotEmpty ||
                              message.embeds.isNotEmpty))
                        _sheetTile(
                          ctx,
                          icon: Icons.translate_rounded,
                          label: message.translatedText != null
                              ? tr('隱藏翻譯結果')
                              : tr('翻譯訊息 (Translate)'),
                          onTap: () async {
                            try {
                              await widget.controller
                                  .translateMessageInline(message);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(trf('翻譯失敗：{0}', [e]))),
                                );
                              }
                            }
                          },
                        ),
                      if (vc.isPluginEnabled('ViewRaw'))
                        _sheetTile(
                          ctx,
                          icon: Icons.code_rounded,
                          label: tr('檢視原始資料 (View Raw)'),
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
                      if (vc.isPluginEnabled('MessageLogger') &&
                          (message.isDeleted || message.editHistory.isNotEmpty))
                        _sheetTile(
                          ctx,
                          icon: Icons.history_toggle_off_rounded,
                          label: tr('清除訊息紀錄 (MessageLogger)'),
                          onTap: () => widget.controller
                              .clearLoggedMessageHistory(message),
                        ),
                    ],
                    [
                      _sheetTile(
                        ctx,
                        icon: Icons.tag_rounded,
                        label: tr('複製訊息 ID'),
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.id));
                        },
                      ),
                      if ((isOwn || widget.canManageMessages) &&
                          !message.isDeleted)
                        _sheetTile(
                          ctx,
                          icon: Icons.delete_outline_rounded,
                          label: tr('刪除訊息'),
                          danger: true,
                          onTap: () => widget.onDelete(message),
                        ),
                    ],
                  ]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _sheetGroups(List<List<Widget>> groups) {
    final palette = widget.palette;
    final out = <Widget>[];
    for (final g in groups) {
      if (g.isEmpty) continue;
      if (out.isNotEmpty) out.add(const SizedBox(height: 10));
      final rows = <Widget>[];
      for (var i = 0; i < g.length; i++) {
        if (i > 0) rows.add(Divider(height: 1, color: palette.border));
        rows.add(g[i]);
      }
      out.add(Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.sidebarBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ));
    }
    return out;
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
    final transformFakeNitro = vc.isPluginEnabled('FakeNitro') &&
        vc.getSetting<bool>('FakeNitro', 'transformEmojis', true);
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
    final me = widget.currentBotUserId;
    final rawMentions = message.rawJson?['mentions'];
    final mentionsMe = me.isNotEmpty &&
        !message.isDeleted &&
        (message.rawJson?['mention_everyone'] == true ||
            (rawMentions is List &&
                rawMentions.any((u) => u is Map && u['id']?.toString() == me)));

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
                      trf('{0}年{1}月{2}日', [message.timestamp.year, message.timestamp.month, message.timestamp.day]),
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

          Listener(
            onPointerDown: (e) {
              _swipeStart = e.position;
              _swipeActive = false;
            },
            onPointerMove: _onSwipeMove,
            onPointerUp: (_) => _onSwipeEnd(),
            onPointerCancel: (_) => _onSwipeEnd(),
            child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _showDiscordMessageSheet(context),
            child: Stack(
              alignment: Alignment.centerRight,
              children: [
                if (mentionsMe)
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x1FF0B232),
                        border: Border(
                          left: BorderSide(color: Color(0xFFF0B232), width: 2),
                        ),
                      ),
                    ),
                  ),
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
                                        ? tr('點擊查看附件')
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
                                            Text(
                                              tr('(已刪除)'),
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
                                            trf('{0}  (編輯前 {1}:{2})', [edit.content, eh, em]),
                                            style: TextStyle(
                                              color: palette.textSecondary,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                      );
                                    }),

                                  if (message.content.isNotEmpty &&
                                      !message.embeds.any((e) =>
                                          e.isMediaOnly &&
                                          e.url != null &&
                                          e.url == message.content.trim()))
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
                                            ? trf('{0} *(已刪除)*', [message.content])
                                            : (message.editedTimestamp != null
                                                ? trf('{0} *(已編輯)*', [message.content])
                                                : message.content),
                                        palette: palette,
                                        guild: widget.guild,
                                        ecoMode: widget.ecoMode,
                                        revealAllSpoilers: revealSpoilers,
                                        alwaysAnimate: alwaysAnim,
                                        roleColorMentions: roleColorMentions,
                                        transformFakeNitroEmojis:
                                            transformFakeNitro,
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

                                  // CV2 messages place their attachments inside components.
                                  if (message.attachments.isNotEmpty &&
                                      !message.isComponentsV2)
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
                                                  deletedBytes: message.isDeleted
                                                      ? widget.controller
                                                          .loggedImageBytes(
                                                              att.id)
                                                      : null,
                                                  onOpen: () {
                                                    final imgs = message
                                                        .attachments
                                                        .where((a) => a.isImage)
                                                        .toList();
                                                    _openMedia(
                                                      [
                                                        for (final a in imgs)
                                                          MediaViewerItem(
                                                            a.previewUrl(
                                                                maxWidth: 2048),
                                                            originalUrl: a.url,
                                                          ),
                                                      ],
                                                      imgs.indexOf(att),
                                                    );
                                                  },
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
                                            .where((emb) {
                                              if (!transformFakeNitro) {
                                                return true;
                                              }
                                              final imgUrl = emb.imageUrl ??
                                                  emb.thumbnailUrl ??
                                                  emb.url;
                                              final isBareEmojiEmbed = emb
                                                          .title ==
                                                      null &&
                                                  emb.description == null &&
                                                  imgUrl != null &&
                                                  RegExp(r'/emojis/\d+\.(?:webp|png|gif)')
                                                      .hasMatch(imgUrl);
                                              return !isBareEmojiEmbed;
                                            })
                                            .map((emb) => _EmbedCard(
                                                  embed: emb,
                                                  palette: palette,
                                                  guild: widget.guild,
                                                  ecoMode: widget.ecoMode,
                                                  alwaysAnimate: alwaysAnim,
                                                  onOpenImage: (url) =>
                                                      _openMedia(
                                                    [MediaViewerItem(url)],
                                                    0,
                                                  ),
                                                ))
                                            .toList(),
                                      ),
                                    ),

                                  if (message.rawJson?['components']
                                          is List &&
                                      (message.rawJson!['components'] as List)
                                          .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: DiscordComponentsView(
                                        components: message
                                            .rawJson!['components'] as List,
                                        attachments: message.attachments,
                                        palette: palette,
                                        guild: widget.guild,
                                        ecoMode: widget.ecoMode,
                                        alwaysAnimate: alwaysAnim,
                                        onOpenMedia: _openMedia,
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
                                        }).followedBy([
                                          // Official "add reaction" pill.
                                          InkWell(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            onTap: () =>
                                                _showCustomEmojiPicker(context),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 3),
                                              decoration: BoxDecoration(
                                                color: palette.cardBg,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: palette.border),
                                              ),
                                              child: Icon(
                                                Icons.add_reaction_outlined,
                                                size: 17,
                                                color: palette.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ]).toList(),
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
  final VoidCallback onOpen;
  /// MessageLogger copy of a deleted image (CDN no longer serves it).
  final Uint8List? deletedBytes;

  const _AttachmentView({
    required this.attachment,
    required this.palette,
    required this.ecoMode,
    required this.onOpen,
    this.deletedBytes,
  });

  @override
  Widget build(BuildContext context) {
    if (attachment.isImage) {
      final maxW = ecoMode ? 360 : 640;
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: GestureDetector(
          onTap: onOpen,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 300),
              child: deletedBytes != null
                  ? Image.memory(deletedBytes!, fit: BoxFit.cover)
                  : Image.network(
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

/// Public read-only embed renderer (used by the message editor preview).
class DiscordEmbedPreview extends StatelessWidget {
  final DiscordEmbed embed;
  final DiscordPalette palette;

  const DiscordEmbedPreview({
    super.key,
    required this.embed,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) => _EmbedCard(
        embed: embed,
        palette: palette,
        ecoMode: false,
        onOpenImage: (_) {},
      );
}

class _EmbedCard extends StatelessWidget {
  final DiscordEmbed embed;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final bool ecoMode;
  final bool alwaysAnimate;
  final void Function(String url) onOpenImage;

  const _EmbedCard({
    required this.embed,
    required this.palette,
    this.guild,
    required this.ecoMode,
    this.alwaysAnimate = false,
    required this.onOpenImage,
  });

  void _open(String? url) {
    final uri = url != null ? Uri.tryParse(url) : null;
    if (uri != null) launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  String? _footerTime() {
    final ts = embed.timestamp;
    if (ts == null) return null;
    final t = DateTime.tryParse(ts)?.toLocal();
    if (t == null) return null;
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return trf('今天 {0}:{1}', [hh, mm]);
    }
    return '${t.year}/${t.month}/${t.day} $hh:$mm';
  }

  Widget _image(String url, {double maxHeight = 300, bool gif = false}) {
    return GestureDetector(
      onTap: () => onOpenImage(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 400),
          child: Stack(
            children: [
              Image.network(
                url,
                cacheWidth: ecoMode ? 480 : 800,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              if (gif)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xAA000000),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'GIF',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Official field grid: inline fields share a row (max 3), others full width.
  Widget _fields() {
    final rows = <List<DiscordEmbedField>>[];
    for (final f in embed.fields) {
      if (f.inline && rows.isNotEmpty) {
        final last = rows.last;
        if (last.length < 3 && last.every((x) => x.inline)) {
          last.add(f);
          continue;
        }
      }
      rows.add([f]);
    }
    Widget field(DiscordEmbedField f) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DiscordMarkdownView(
              text: '**${f.name}**',
              palette: palette,
              guild: guild,
              ecoMode: ecoMode,
              alwaysAnimate: alwaysAnimate,
              fontSize: 13.5,
            ),
            const SizedBox(height: 2),
            DiscordMarkdownView(
              text: f.value,
              palette: palette,
              guild: guild,
              ecoMode: ecoMode,
              alwaysAnimate: alwaysAnimate,
              fontSize: 13.5,
            ),
          ],
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: row.length == 1
                ? field(row.first)
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < row.length; i++) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(child: field(row[i])),
                      ],
                    ],
                  ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // GIF / image link embeds: just the media, no card (official behaviour).
    if (embed.isMediaOnly) {
      final url = embed.thumbnailUrl ?? embed.imageUrl;
      if (url == null || url.isEmpty) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: _image(url, gif: embed.type == 'gifv'),
      );
    }

    final accent = embed.color != null
        ? Color(0xFF000000 | embed.color!)
        : const Color(0xFF1E1F22);
    final footerTime = _footerTime();
    final footerParts = [
      if (embed.footerText != null && embed.footerText!.isNotEmpty)
        embed.footerText!,
      if (footerTime != null) footerTime,
    ];
    final bigThumb = embed.type == 'video' || embed.type == 'article';

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxWidth: 432),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
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
                    if (embed.providerName != null &&
                        embed.providerName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          embed.providerName!,
                          style:
                              TextStyle(color: palette.textMuted, fontSize: 12),
                        ),
                      ),
                    if (embed.authorName != null &&
                        embed.authorName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: GestureDetector(
                          onTap: embed.authorUrl != null
                              ? () => _open(embed.authorUrl)
                              : null,
                          child: Row(
                            children: [
                              if (embed.authorIconUrl != null &&
                                  embed.authorIconUrl!.isNotEmpty) ...[
                                ClipOval(
                                  child: Image.network(
                                    embed.authorIconUrl!,
                                    width: 22,
                                    height: 22,
                                    cacheWidth: 44,
                                    errorBuilder: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: Text(
                                  embed.authorName!,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (embed.title != null && embed.title!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: embed.url != null
                            ? GestureDetector(
                                onTap: () => _open(embed.url),
                                child: DiscordMarkdownView(
                                  text: '**${embed.title!}**',
                                  palette: palette,
                                  guild: guild,
                                  ecoMode: ecoMode,
                                  alwaysAnimate: alwaysAnimate,
                                  fontSize: 15,
                                  overrideTextColor: const Color(0xFF00A8FC),
                                ),
                              )
                            : DiscordMarkdownView(
                                text: '**${embed.title!}**',
                                palette: palette,
                                guild: guild,
                                ecoMode: ecoMode,
                                alwaysAnimate: alwaysAnimate,
                                fontSize: 15,
                              ),
                      ),
                    if (embed.description != null &&
                        embed.description!.isNotEmpty)
                      DiscordMarkdownView(
                        text: embed.description!,
                        palette: palette,
                        guild: guild,
                        ecoMode: ecoMode,
                        alwaysAnimate: alwaysAnimate,
                        fontSize: 14,
                      ),
                  ],
                ),
              ),
              if (!bigThumb &&
                  embed.thumbnailUrl != null &&
                  embed.thumbnailUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: GestureDetector(
                    onTap: () => onOpenImage(embed.thumbnailUrl!),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.network(
                        embed.thumbnailUrl!,
                        width: 80,
                        height: 80,
                        cacheWidth: 160,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (embed.fields.isNotEmpty) _fields(),
          if (embed.imageUrl != null && embed.imageUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _image(embed.imageUrl!),
            )
          else if (bigThumb &&
              embed.thumbnailUrl != null &&
              embed.thumbnailUrl!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _image(embed.thumbnailUrl!),
            ),
          if (footerParts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  if (embed.footerIconUrl != null &&
                      embed.footerIconUrl!.isNotEmpty) ...[
                    ClipOval(
                      child: Image.network(
                        embed.footerIconUrl!,
                        width: 18,
                        height: 18,
                        cacheWidth: 36,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      footerParts.join(' • '),
                      style: TextStyle(color: palette.textMuted, fontSize: 12),
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
