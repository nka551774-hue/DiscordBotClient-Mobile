import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';

class DiscordMarkdownView extends StatelessWidget {
  final String text;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final bool ecoMode;
  final double fontSize;
  final bool revealAllSpoilers;
  final bool alwaysAnimate;
  final bool roleColorMentions;
  final Color? overrideTextColor;
  final void Function(String userId)? onTapUserMention;

  const DiscordMarkdownView({
    super.key,
    required this.text,
    required this.palette,
    this.guild,
    this.ecoMode = true,
    this.fontSize = 15,
    this.revealAllSpoilers = false,
    this.alwaysAnimate = false,
    this.roleColorMentions = false,
    this.overrideTextColor,
    this.onTapUserMention,
  });

  static final RegExp _codeBlockRegex =
      RegExp(r'```(?:([a-zA-Z0-9_+-]+)\n)?([\s\S]*?)```');

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final matches = _codeBlockRegex.allMatches(text).toList();
    if (matches.isEmpty) {
      return _RichParagraph(
        text: text,
        palette: palette,
        guild: guild,
        ecoMode: ecoMode,
        fontSize: fontSize,
        revealAllSpoilers: revealAllSpoilers,
        alwaysAnimate: alwaysAnimate,
        roleColorMentions: roleColorMentions,
        overrideTextColor: overrideTextColor,
        onTapUserMention: onTapUserMention,
      );
    }

    final children = <Widget>[];
    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        final before = text.substring(cursor, m.start).trim();
        if (before.isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _RichParagraph(
              text: before,
              palette: palette,
              guild: guild,
              ecoMode: ecoMode,
              fontSize: fontSize,
              revealAllSpoilers: revealAllSpoilers,
              alwaysAnimate: alwaysAnimate,
              roleColorMentions: roleColorMentions,
              overrideTextColor: overrideTextColor,
              onTapUserMention: onTapUserMention,
            ),
          ));
        }
      }
      final lang = m.group(1) ?? '';
      final code = (m.group(2) ?? '').trimRight();
      children.add(_CodeBlockBox(
        language: lang,
        code: code,
        palette: palette,
      ));
      cursor = m.end;
    }

    if (cursor < text.length) {
      final rest = text.substring(cursor).trim();
      if (rest.isNotEmpty) {
        children.add(Padding(
          padding: const EdgeInsets.only(top: 6),
          child: _RichParagraph(
            text: rest,
            palette: palette,
            guild: guild,
            ecoMode: ecoMode,
            fontSize: fontSize,
            revealAllSpoilers: revealAllSpoilers,
            alwaysAnimate: alwaysAnimate,
            roleColorMentions: roleColorMentions,
            overrideTextColor: overrideTextColor,
            onTapUserMention: onTapUserMention,
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

class _CodeBlockBox extends StatelessWidget {
  final String language;
  final String code;
  final DiscordPalette palette;

  const _CodeBlockBox({
    required this.language,
    required this.code,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: palette.oled ? const Color(0xFF0A0C10) : const Color(0xFF1E1F22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: palette.border)),
            ),
            child: Row(
              children: [
                Text(
                  language.isEmpty ? 'code' : language,
                  style: TextStyle(
                    color: palette.textMuted,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已複製程式碼'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              code,
              style: const TextStyle(
                color: Color(0xFFE3E5E8),
                fontSize: 13,
                fontFamily: 'monospace',
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RichParagraph extends StatefulWidget {
  final String text;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final bool ecoMode;
  final double fontSize;
  final bool revealAllSpoilers;
  final bool alwaysAnimate;
  final bool roleColorMentions;
  final Color? overrideTextColor;
  final void Function(String userId)? onTapUserMention;

  const _RichParagraph({
    required this.text,
    required this.palette,
    this.guild,
    required this.ecoMode,
    required this.fontSize,
    this.revealAllSpoilers = false,
    this.alwaysAnimate = false,
    this.roleColorMentions = false,
    this.overrideTextColor,
    this.onTapUserMention,
  });

  @override
  State<_RichParagraph> createState() => _RichParagraphState();
}

class _RichParagraphState extends State<_RichParagraph> {
  final Set<int> _revealedSpoilers = <int>{};

  static final RegExp _tokenRegex = RegExp(
    r'(\|\|.+?\|\|)|(`[^`\n]+`)|(\*\*.+?\*\*)|(__.+?__)|(~~.+?~~)|(\*[^*\n]+\*)|(<a?:[a-zA-Z0-9_]+:\d+>)|(<@!?\d+>)|(<#\d+>)|(<@&\d+>)|(<t:\d+(?::[a-zA-Z])?>)|(https?://[^\s<>]+)',
  );

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: widget.overrideTextColor ?? widget.palette.textPrimary,
      fontSize: widget.fontSize,
      height: 1.36,
    );

    final lines = widget.text.split('\n');
    final spans = <InlineSpan>[];
    int spoilerCounter = 0;

    for (int i = 0; i < lines.length; i++) {
      var line = lines[i];
      TextStyle lineStyle = baseStyle;

      if (line.startsWith('### ')) {
        line = line.substring(4);
        lineStyle = baseStyle.copyWith(
          fontSize: widget.fontSize + 2,
          fontWeight: FontWeight.w700,
        );
      } else if (line.startsWith('## ')) {
        line = line.substring(3);
        lineStyle = baseStyle.copyWith(
          fontSize: widget.fontSize + 4,
          fontWeight: FontWeight.w700,
        );
      } else if (line.startsWith('# ')) {
        line = line.substring(2);
        lineStyle = baseStyle.copyWith(
          fontSize: widget.fontSize + 6,
          fontWeight: FontWeight.w800,
        );
      } else if (line.startsWith('> ')) {
        spans.add(TextSpan(
          text: '▎ ',
          style: lineStyle.copyWith(
            color: widget.palette.textMuted,
            fontWeight: FontWeight.w900,
          ),
        ));
        line = line.substring(2);
        lineStyle = lineStyle.copyWith(color: widget.palette.textSecondary);
      }

      int idx = 0;
      for (final match in _tokenRegex.allMatches(line)) {
        if (match.start > idx) {
          spans.add(TextSpan(
            text: line.substring(idx, match.start),
            style: lineStyle,
          ));
        }

        final token = match.group(0)!;
        if (token.startsWith('||') && token.endsWith('||')) {
          final currentSpoilerIdx = spoilerCounter++;
          final revealed = widget.revealAllSpoilers ||
              _revealedSpoilers.contains(currentSpoilerIdx);
          final inner = token.substring(2, token.length - 2);
          spans.add(TextSpan(
            text: revealed ? inner : ' 劇透內容 ',
            style: lineStyle.copyWith(
              backgroundColor: revealed
                  ? const Color(0xFF2B2D31)
                  : const Color(0xFF1E1F22),
              color: revealed ? widget.palette.textPrimary : widget.palette.textMuted,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                setState(() {
                  _revealedSpoilers.add(currentSpoilerIdx);
                });
              },
          ));
        } else if (token.startsWith('`') && token.endsWith('`')) {
          spans.add(TextSpan(
            text: ' ${token.substring(1, token.length - 1)} ',
            style: lineStyle.copyWith(
              fontFamily: 'monospace',
              fontSize: widget.fontSize - 1.5,
              backgroundColor: widget.palette.oled
                  ? const Color(0xFF161922)
                  : const Color(0xFF1E1F22),
            ),
          ));
        } else if (token.startsWith('**') && token.endsWith('**')) {
          spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: lineStyle.copyWith(fontWeight: FontWeight.w700),
          ));
        } else if (token.startsWith('__') && token.endsWith('__')) {
          spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: lineStyle.copyWith(decoration: TextDecoration.underline),
          ));
        } else if (token.startsWith('~~') && token.endsWith('~~')) {
          spans.add(TextSpan(
            text: token.substring(2, token.length - 2),
            style: lineStyle.copyWith(decoration: TextDecoration.lineThrough),
          ));
        } else if (token.startsWith('*') && token.endsWith('*')) {
          spans.add(TextSpan(
            text: token.substring(1, token.length - 1),
            style: lineStyle.copyWith(fontStyle: FontStyle.italic),
          ));
        } else if (token.startsWith('<:') || token.startsWith('<a:')) {
          final animated = token.startsWith('<a:');
          final parts = token.substring(1, token.length - 1).split(':');
          if (parts.length >= 3) {
            final emojiId = parts[2];
            final ext = (animated && (!widget.ecoMode || widget.alwaysAnimate))
                ? 'gif'
                : 'webp';
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Image.network(
                  'https://cdn.discordapp.com/emojis/$emojiId.$ext?size=40',
                  width: 20,
                  height: 20,
                  cacheWidth: 40,
                  errorBuilder: (_, __, ___) =>
                      Text(':${parts[1]}:', style: lineStyle),
                ),
              ),
            ));
          }
        } else if (token.startsWith('<@&')) {
          final roleId = token.substring(3, token.length - 1);
          final role = widget.guild?.roles[roleId];
          final roleColor = (role != null && role.color != 0)
              ? Color(0xFF000000 | role.color)
              : DiscordPalette.blurple;
          spans.add(TextSpan(
            text: '@${role?.name ?? 'role'}',
            style: lineStyle.copyWith(
              color: roleColor,
              backgroundColor: roleColor.withAlpha(38),
              fontWeight: FontWeight.w600,
            ),
          ));
        } else if (token.startsWith('<@')) {
          final uid = token
              .replaceAll('<@!', '')
              .replaceAll('<@', '')
              .replaceAll('>', '');
          final member = widget.guild?.cachedMembers[uid];
          final resolvedName = member?.effectiveName ?? uid;
          final rc = (widget.roleColorMentions && widget.guild != null)
              ? member?.resolveColor(widget.guild!.roles)
              : null;
          final mentionColor =
              rc != null ? Color(0xFF000000 | rc) : const Color(0xFFC9CDFB);
          final mentionBg = rc != null
              ? Color(0xFF000000 | rc).withAlpha(42)
              : DiscordPalette.blurple.withAlpha(65);
          spans.add(TextSpan(
            text: '@$resolvedName',
            style: lineStyle.copyWith(
              color: mentionColor,
              backgroundColor: mentionBg,
              fontWeight: FontWeight.w600,
            ),
            recognizer: widget.onTapUserMention != null
                ? (TapGestureRecognizer()
                  ..onTap = () => widget.onTapUserMention!(uid))
                : null,
          ));
        } else if (token.startsWith('<#')) {
          final cid = token.substring(2, token.length - 1);
          String chName = cid;
          if (widget.guild != null) {
            for (final c in widget.guild!.channels) {
              if (c.id == cid) {
                chName = c.name;
                break;
              }
            }
          }
          spans.add(TextSpan(
            text: '#$chName',
            style: lineStyle.copyWith(
              color: const Color(0xFFC9CDFB),
              backgroundColor: DiscordPalette.blurple.withAlpha(65),
              fontWeight: FontWeight.w600,
            ),
          ));
        } else if (token.startsWith('<t:')) {
          final inner = token.substring(3, token.length - 1);
          final secStr = inner.split(':').first;
          final sec = int.tryParse(secStr) ?? 0;
          final dt = DateTime.fromMillisecondsSinceEpoch(sec * 1000).toLocal();
          final formatted =
              '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} '
              '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
          spans.add(TextSpan(
            text: ' $formatted ',
            style: lineStyle.copyWith(
              backgroundColor: const Color(0xFF2B2D31),
              fontSize: widget.fontSize - 1,
            ),
          ));
        } else if (token.startsWith('http://') || token.startsWith('https://')) {
          spans.add(TextSpan(
            text: token,
            style: lineStyle.copyWith(
              color: const Color(0xFF00A8FC),
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final uri = Uri.tryParse(token);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ));
        } else {
          spans.add(TextSpan(text: token, style: lineStyle));
        }

        idx = match.end;
      }

      if (idx < line.length) {
        spans.add(TextSpan(text: line.substring(idx), style: lineStyle));
      }
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}
