import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';
import 'discord_markdown.dart';

class MessageTile extends StatelessWidget {
  final DiscordMessage message;
  final bool compact;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final String currentBotUserId;
  final bool ecoMode;
  final bool canManageMessages;
  final void Function(DiscordMessage msg) onReply;
  final void Function(DiscordMessage msg) onEdit;
  final void Function(DiscordMessage msg) onDelete;
  final void Function(DiscordMessage msg) onTogglePin;
  final void Function(DiscordMessage msg, DiscordEmoji emoji, bool me)
      onToggleReaction;
  final void Function(String userId) onOpenDm;

  const MessageTile({
    super.key,
    required this.message,
    required this.compact,
    required this.palette,
    this.guild,
    required this.currentBotUserId,
    required this.ecoMode,
    required this.canManageMessages,
    required this.onReply,
    required this.onEdit,
    required this.onDelete,
    required this.onTogglePin,
    required this.onToggleReaction,
    required this.onOpenDm,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return '今天 $hh:$mm';
    }
    return '${dt.month}/${dt.day} $hh:$mm';
  }

  void _showActionsSheet(BuildContext context) {
    final isOwn = message.author.id == currentBotUserId;
    const quickEmojis = ['👍', '❤️', '😂', '🔥', '🎉', '👀', '✅'];

    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Emoji Bar
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: quickEmojis.map((em) {
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(ctx).pop();
                          final existing = message.reactions.where(
                            (r) => r.emoji.name == em && r.emoji.id == null,
                          );
                          final alreadyMe =
                              existing.isNotEmpty && existing.first.me;
                          onToggleReaction(
                            message,
                            DiscordEmoji(name: em),
                            alreadyMe,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: palette.cardBg,
                            shape: BoxShape.circle,
                            border: Border.all(color: palette.border),
                          ),
                          child:
                              Text(em, style: const TextStyle(fontSize: 19)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.reply_rounded),
                  title: const Text('回覆訊息'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onReply(message);
                  },
                ),
                if (isOwn)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.edit_outlined),
                    title: const Text('編輯機器人訊息'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onEdit(message);
                    },
                  ),
                if (canManageMessages)
                  ListTile(
                    dense: true,
                    leading: Icon(message.pinned
                        ? Icons.push_pin_outlined
                        : Icons.push_pin_rounded),
                    title: Text(message.pinned ? '取消釘選訊息' : '釘選訊息'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onTogglePin(message);
                    },
                  ),
                if (message.author.id != currentBotUserId)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.mail_outline_rounded),
                    title: Text('開啟與 ${message.author.displayName} 的私訊 (DM)'),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onOpenDm(message.author.id);
                    },
                  ),
                if (message.content.isNotEmpty)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.copy_rounded),
                    title: const Text('複製訊息文字'),
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.content));
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('已複製訊息內容'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.tag_rounded),
                  title: Text('複製訊息 ID (${message.id})'),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.id));
                    Navigator.of(ctx).pop();
                  },
                ),
                if (isOwn || canManageMessages)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.delete_outline_rounded,
                        color: DiscordPalette.red),
                    title: const Text('刪除訊息',
                        style: TextStyle(color: DiscordPalette.red)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onDelete(message);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarPx = ecoMode ? 64 : 96;

    return RepaintBoundary(
      child: InkWell(
        onLongPress: () => _showActionsSheet(context),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            12,
            compact ? 2 : 10,
            12,
            2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Reply Reference Banner
              if (message.referencedMessage != null)
                Padding(
                  padding: const EdgeInsets.only(left: 48, bottom: 3),
                  child: Row(
                    children: [
                      Icon(Icons.subdirectory_arrow_right_rounded,
                          size: 13, color: palette.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '@${message.referencedMessage!.author.displayName}',
                        style: TextStyle(
                          color: palette.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          message.referencedMessage!.content.isEmpty
                              ? '[附件 / Embed]'
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
                  // Left Avatar or Compact Spacer
                  if (!compact)
                    GestureDetector(
                      onTap: message.author.id != currentBotUserId
                          ? () => onOpenDm(message.author.id)
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
                              message.author.displayName.isNotEmpty
                                  ? String.fromCharCode(
                                          message.author.displayName.runes.first)
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

                  const SizedBox(width: 10),

                  // Message Body
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!compact)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              children: [
                                Text(
                                  message.author.displayName,
                                  style: TextStyle(
                                    color: palette.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                                if (message.author.bot)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: DiscordPalette.blurple,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'BOT',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                Text(
                                  _formatTime(message.timestamp),
                                  style: TextStyle(
                                    color: palette.textMuted,
                                    fontSize: 11,
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

                        // Text Content
                        if (message.content.isNotEmpty)
                          DiscordMarkdownView(
                            text: message.editedTimestamp != null
                                ? '${message.content} *(已編輯)*'
                                : message.content,
                            palette: palette,
                            guild: guild,
                            ecoMode: ecoMode,
                          ),

                        // Stickers summary
                        if (message.stickerNames.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: palette.cardBg,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: palette.border),
                              ),
                              child: Text(
                                '✨ 貼圖：${message.stickerNames.join(', ')}',
                                style: TextStyle(
                                    color: palette.textSecondary, fontSize: 12),
                              ),
                            ),
                          ),

                        // Attachments
                        if (message.attachments.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: message.attachments
                                  .map((att) => _AttachmentView(
                                        attachment: att,
                                        palette: palette,
                                        ecoMode: ecoMode,
                                      ))
                                  .toList(),
                            ),
                          ),

                        // Rich Embeds
                        if (message.embeds.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: message.embeds
                                  .map((emb) => _EmbedCard(
                                        embed: emb,
                                        palette: palette,
                                        guild: guild,
                                        ecoMode: ecoMode,
                                      ))
                                  .toList(),
                            ),
                          ),

                        // Component Buttons
                        if (message.components.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: message.components.map((btn) {
                                return OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    backgroundColor: btn.style == 1
                                        ? DiscordPalette.blurple
                                        : palette.cardBg,
                                    foregroundColor: Colors.white,
                                    side: BorderSide(color: palette.border),
                                  ),
                                  onPressed: btn.url != null
                                      ? () {
                                          final uri = Uri.tryParse(btn.url!);
                                          if (uri != null) {
                                            launchUrl(uri,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          }
                                        }
                                      : null,
                                  child: Text(
                                    btn.label ?? '元件按鈕',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),

                        // Reactions Bar
                        if (message.reactions.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: message.reactions.map((rxn) {
                                final customUrl = rxn.emoji.imageUrl(
                                  size: 32,
                                  allowAnimated: !ecoMode,
                                );
                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => onToggleReaction(
                                      message, rxn.emoji, rxn.me),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: rxn.me
                                          ? DiscordPalette.blurple.withAlpha(55)
                                          : palette.cardBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: rxn.me
                                            ? DiscordPalette.blurple
                                            : palette.border,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
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
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${rxn.count}',
                                          style: TextStyle(
                                            color: rxn.me
                                                ? Colors.white
                                                : palette.textSecondary,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
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
            borderRadius: BorderRadius.circular(10),
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
        : DiscordPalette.blurple;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: accent, width: 4),
          top: BorderSide(color: palette.border, width: 0.6),
          right: BorderSide(color: palette.border, width: 0.6),
          bottom: BorderSide(color: palette.border, width: 0.6),
        ),
      ),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (embed.authorName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                embed.authorName!,
                style: TextStyle(
                  color: palette.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (embed.title != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: GestureDetector(
                onTap: embed.url != null
                    ? () {
                        final uri = Uri.tryParse(embed.url!);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
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
          if (embed.description != null && embed.description!.isNotEmpty)
            DiscordMarkdownView(
              text: embed.description!,
              palette: palette,
              guild: guild,
              ecoMode: ecoMode,
              fontSize: 13.5,
            ),
          if (embed.fields.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                children: embed.fields.map((f) {
                  return SizedBox(
                    width: f.inline ? 140 : double.infinity,
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
                borderRadius: BorderRadius.circular(6),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 200),
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
              child: Text(
                embed.footerText!,
                style: TextStyle(color: palette.textMuted, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }
}
