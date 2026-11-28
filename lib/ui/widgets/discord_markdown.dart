import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';
import '../../l10n/strings.dart';


/// Twemoji 15.1 asset for a unicode emoji (the set Discord itself bundles;
/// shipped in the app by CI, so it renders instantly and offline).
/// File name rule: drop FE0F unless the sequence has a ZWJ.
String twemojiAsset(String emoji) {
  final runes = emoji.runes.toList();
  final cps = runes.contains(0x200D)
      ? runes
      : runes.where((r) => r != 0xFE0F).toList();
  final name = cps.map((r) => r.toRadixString(16)).join('-');
  return 'assets/twemoji/$name.png';
}

/// Emoji image with a text fallback when no Twemoji file exists.
Widget twemojiImage(String emoji, double size, {TextStyle? fallbackStyle}) {
  return Image.asset(
    twemojiAsset(emoji),
    width: size,
    height: size,
    cacheWidth: 72,
    filterQuality: FilterQuality.medium,
    errorBuilder: (_, __, ___) => Text(
      emoji,
      style: fallbackStyle ?? TextStyle(fontSize: size * 0.8),
    ),
  );
}

class DiscordMarkdownView extends StatelessWidget {
  final String text;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final bool ecoMode;
  final double fontSize;
  final bool revealAllSpoilers;
  final bool alwaysAnimate;
  final bool roleColorMentions;
  final bool transformFakeNitroEmojis;
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
    this.transformFakeNitroEmojis = true,
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
        transformFakeNitroEmojis: transformFakeNitroEmojis,
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
              transformFakeNitroEmojis: transformFakeNitroEmojis,
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
            transformFakeNitroEmojis: transformFakeNitroEmojis,
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
                      SnackBar(
                        content: Text(tr('已複製程式碼')),
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
  final bool transformFakeNitroEmojis;
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
    this.transformFakeNitroEmojis = true,
    this.overrideTextColor,
    this.onTapUserMention,
  });

  @override
  State<_RichParagraph> createState() => _RichParagraphState();
}

class _RichParagraphState extends State<_RichParagraph> {
  final Set<int> _revealedSpoilers = <int>{};
  // Parsed result; chat tiles rebuild on every controller tick, so re-parse
  // only when an input that affects the output changes.
  Widget? _cached;

  @override
  void didUpdateWidget(covariant _RichParagraph old) {
    super.didUpdateWidget(old);
    final w = widget;
    if (w.text != old.text ||
        w.fontSize != old.fontSize ||
        w.ecoMode != old.ecoMode ||
        w.revealAllSpoilers != old.revealAllSpoilers ||
        w.alwaysAnimate != old.alwaysAnimate ||
        w.roleColorMentions != old.roleColorMentions ||
        w.transformFakeNitroEmojis != old.transformFakeNitroEmojis ||
        w.overrideTextColor != old.overrideTextColor ||
        w.palette.textPrimary != old.palette.textPrimary ||
        w.palette.textMuted != old.palette.textMuted ||
        !identical(w.guild?.roles, old.guild?.roles) ||
        !identical(w.guild?.cachedMembers, old.guild?.cachedMembers)) {
      _cached = null;
    }
  }

  static final RegExp _tokenRegex = RegExp(
    r'(\|\|.+?\|\|)|(`[^`\n]+`)|(<a?:[^:>\s]+:\d+>)|(\[[^\[\]\n]+\]\(https?://(?:cdn\.discordapp\.com|media\.discordapp\.net)/emojis/\d+\.(?:webp|png|gif)[^\)\s]*\))|(\[[^\[\]\n]+\]\(<?https?://[^\s)>]+>?\))|(\*\*\*.+?\*\*\*)|(\*\*.+?\*\*)|(__.+?__)|(~~.+?~~)|(\*[^*\n]+\*)|(<@!?\d+>)|(<#\d+>)|(<@&\d+>)|(<t:\d+(?::[a-zA-Z])?>)|(https?://[^\s<>]+)',
  );

  static final RegExp _fakeNitroHyperlinkRegex = RegExp(
    r'^\[([^\[\]\n]+)\]\((https?://(?:cdn\.discordapp\.com|media\.discordapp\.net)/emojis/(\d+)\.(webp|png|gif)[^\)\s]*)\)$',
  );

  static final RegExp _fakeNitroBareUrlRegex = RegExp(
    r'^https?://(?:cdn\.discordapp\.com|media\.discordapp\.net)/emojis/(\d+)\.(webp|png|gif)(?:\?[^\s<>]*)?$',
  );

  static final RegExp _maskedLinkRegex =
      RegExp(r'^\[([^\[\]\n]+)\]\(<?(https?://[^\s)>]+)>?\)$');

  /// One rendered emoji (incl. ZWJ sequences, skin tones, flags, keycaps).
  static final RegExp _unicodeEmojiRegex = RegExp(
    r'\p{Regional_Indicator}{2}|(?:\p{Extended_Pictographic}|[0-9#*]️?⃣)(?:️|‍|\p{Emoji_Modifier}|\p{Extended_Pictographic}|⃣|[\u{E0020}-\u{E007F}])*',
    unicode: true,
  );

  static final RegExp _customEmojiTokenRegex = RegExp(
    r'<a?:[^:>\s]+:\d+>|\[[^\[\]\n]+\]\(https?://(?:cdn\.discordapp\.com|media\.discordapp\.net)/emojis/\d+\.(?:webp|png|gif)[^\)\s]*\)|https?://(?:cdn\.discordapp\.com|media\.discordapp\.net)/emojis/\d+\.(?:webp|png|gif)(?:\?[^\s<>]*)?',
  );

  /// Official rule: a message made only of (≤ 30) emojis renders them jumbo.
  static bool _isJumboOnly(String text) {
    final body = text
        .replaceAll(tr('*(已編輯)*'), '')
        .replaceAll(tr('*(已刪除)*'), '');
    var count = _customEmojiTokenRegex.allMatches(body).length;
    final noCustom = body.replaceAll(_customEmojiTokenRegex, '');
    count += _unicodeEmojiRegex.allMatches(noCustom).length;
    if (count == 0 || count > 30) return false;
    return noCustom.replaceAll(_unicodeEmojiRegex, '').trim().isEmpty;
  }

  /// Twemoji file name rule: drop FE0F unless the sequence has a ZWJ.

  /// Plain text with unicode emoji drawn bigger, like the official client.
  void _addPlain(
    List<InlineSpan> spans,
    String text,
    TextStyle style,
    double emojiFontSize,
  ) {
    var i = 0;
    for (final m in _unicodeEmojiRegex.allMatches(text)) {
      if (m.start > i) {
        spans.add(TextSpan(text: text.substring(i, m.start), style: style));
      }
      final emoji = m.group(0)!;
      final runes = emoji.runes.toList();
      final emojiStyle =
          style.copyWith(fontSize: emojiFontSize, height: 1.15);
      // Text-presentation symbols (©, ™, ↔ … without FE0F) stay plain text.
      if (runes.length == 1 && runes.first < 0x1F000) {
        spans.add(TextSpan(text: emoji, style: emojiStyle));
      } else {
        // Official client draws unicode emoji as Twemoji images, so emoji the
        // system font lacks (older Android) still render.
        final size = emojiFontSize * 1.12;
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: twemojiImage(emoji, size, fallbackStyle: emojiStyle),
          ),
        ));
      }
      i = m.end;
    }
    if (i < text.length) {
      spans.add(TextSpan(text: text.substring(i), style: style));
    }
  }

  // Spoiler index across one build (nested formatting recurses via _inline).
  int _spoilerCounter = 0;

  /// Tokenises one line; bold / italic / underline / strike recurse so emoji,
  /// mentions and links inside formatting (common in embeds) still render.
  void _inline(
    String line,
    TextStyle lineStyle,
    List<InlineSpan> spans,
    double emojiDisplaySize,
    int emojiFetchSize,
    double unicodeEmojiFont,
  ) {
      int idx = 0;
      for (final match in _tokenRegex.allMatches(line)) {
        if (match.start > idx) {
          _addPlain(spans, line.substring(idx, match.start), lineStyle,
              unicodeEmojiFont);
        }

        final token = match.group(0)!;
        if (token.startsWith('||') && token.endsWith('||')) {
          final currentSpoilerIdx = _spoilerCounter++;
          final revealed = widget.revealAllSpoilers ||
              _revealedSpoilers.contains(currentSpoilerIdx);
          final inner = token.substring(2, token.length - 2);
          spans.add(TextSpan(
            text: revealed ? inner : tr(' 劇透內容 '),
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
                  _cached = null;
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
        } else if (token.length > 6 &&
            token.startsWith('***') &&
            token.endsWith('***')) {
          _inline(
            token.substring(3, token.length - 3),
            lineStyle.copyWith(
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
            spans, emojiDisplaySize, emojiFetchSize, unicodeEmojiFont,
          );
        } else if (token.startsWith('**') && token.endsWith('**')) {
          _inline(token.substring(2, token.length - 2), lineStyle.copyWith(fontWeight: FontWeight.w700),
              spans, emojiDisplaySize, emojiFetchSize, unicodeEmojiFont);
        } else if (token.startsWith('__') && token.endsWith('__')) {
          _inline(token.substring(2, token.length - 2), lineStyle.copyWith(decoration: TextDecoration.underline),
              spans, emojiDisplaySize, emojiFetchSize, unicodeEmojiFont);
        } else if (token.startsWith('~~') && token.endsWith('~~')) {
          _inline(token.substring(2, token.length - 2), lineStyle.copyWith(decoration: TextDecoration.lineThrough),
              spans, emojiDisplaySize, emojiFetchSize, unicodeEmojiFont);
        } else if (token.startsWith('*') && token.endsWith('*')) {
          _inline(token.substring(1, token.length - 1), lineStyle.copyWith(fontStyle: FontStyle.italic),
              spans, emojiDisplaySize, emojiFetchSize, unicodeEmojiFont);
        } else if (token.startsWith('<:') || token.startsWith('<a:')) {
          final animated = token.startsWith('<a:');
          final parts = token.substring(1, token.length - 1).split(':');
          if (parts.length >= 3) {
            final emojiName = parts[1];
            final emojiId = parts.last;
            final ext = (animated && (!widget.ecoMode || widget.alwaysAnimate))
                ? 'gif'
                : 'webp';
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Tooltip(
                message: ':$emojiName:',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Image.network(
                    'https://cdn.discordapp.com/emojis/$emojiId.$ext?size=$emojiFetchSize',
                    width: emojiDisplaySize,
                    height: emojiDisplaySize,
                    cacheWidth: emojiFetchSize,
                    errorBuilder: (_, __, ___) =>
                        Text(':$emojiName:', style: lineStyle),
                  ),
                ),
              ),
            ));
          }
        } else if (token.startsWith('[') &&
            _fakeNitroHyperlinkRegex.hasMatch(token)) {
          final fnMatch = _fakeNitroHyperlinkRegex.firstMatch(token)!;
          final label = fnMatch.group(1)!;
          final fullUrl = fnMatch.group(2)!;
          final emojiId = fnMatch.group(3)!;
          final origExt = fnMatch.group(4)!;
          if (widget.transformFakeNitroEmojis) {
            final ext =
                (origExt == 'gif' && (!widget.ecoMode || widget.alwaysAnimate))
                    ? 'gif'
                    : 'webp';
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Tooltip(
                message: ':$label:',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Image.network(
                    'https://cdn.discordapp.com/emojis/$emojiId.$ext?size=$emojiFetchSize',
                    width: emojiDisplaySize,
                    height: emojiDisplaySize,
                    cacheWidth: emojiFetchSize,
                    errorBuilder: (_, __, ___) =>
                        Text(':$label:', style: lineStyle),
                  ),
                ),
              ),
            ));
          } else {
            spans.add(TextSpan(
              text: label,
              style: lineStyle.copyWith(
                color: const Color(0xFF00A8FC),
                decoration: TextDecoration.underline,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  final uri = Uri.tryParse(fullUrl);
                  if (uri != null) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
            ));
          }
        } else if (token.startsWith('[') &&
            _maskedLinkRegex.hasMatch(token)) {
          final ml = _maskedLinkRegex.firstMatch(token)!;
          final label = ml.group(1)!;
          final href = ml.group(2)!;
          spans.add(TextSpan(
            text: label,
            style: lineStyle.copyWith(color: const Color(0xFF00A8FC)),
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                final uri = Uri.tryParse(href);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
          ));
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
          final bareEmoji = widget.transformFakeNitroEmojis
              ? _fakeNitroBareUrlRegex.firstMatch(token)
              : null;
          if (bareEmoji != null) {
            final emojiId = bareEmoji.group(1)!;
            final origExt = bareEmoji.group(2)!;
            final ext =
                (origExt == 'gif' && (!widget.ecoMode || widget.alwaysAnimate))
                    ? 'gif'
                    : 'webp';
            spans.add(WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Image.network(
                  'https://cdn.discordapp.com/emojis/$emojiId.$ext?size=$emojiFetchSize',
                  width: emojiDisplaySize,
                  height: emojiDisplaySize,
                  cacheWidth: emojiFetchSize,
                  errorBuilder: (_, __, ___) =>
                      Text(token, style: lineStyle),
                ),
              ),
            ));
          } else {
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
          }
        } else {
          spans.add(TextSpan(text: token, style: lineStyle));
        }

        idx = match.end;
      }

      if (idx < line.length) {
        _addPlain(spans, line.substring(idx), lineStyle, unicodeEmojiFont);
      }
  }

  @override
  Widget build(BuildContext context) => _cached ??= _buildRich();

  Widget _buildRich() {
    final baseStyle = TextStyle(
      color: widget.overrideTextColor ?? widget.palette.textPrimary,
      fontSize: widget.fontSize,
      height: 1.36,
    );
    final isJumbo = _isJumboOnly(widget.text);
    final emojiDisplaySize = isJumbo ? 48.0 : 22.0;
    final emojiFetchSize = isJumbo ? 96 : 48;
    final unicodeEmojiFont = isJumbo ? 42.0 : widget.fontSize * 1.3;

    final lines = widget.text.split('\n');
    final spans = <InlineSpan>[];
    _spoilerCounter = 0;

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
      } else if (line.startsWith('-# ')) {
        line = line.substring(3);
        lineStyle = baseStyle.copyWith(
          fontSize: widget.fontSize - 2.5,
          color: widget.palette.textMuted,
        );
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        spans.add(TextSpan(text: '  •  ', style: lineStyle));
        line = line.substring(2);
      } else if (line.startsWith('>>> ')) {
        spans.add(TextSpan(
          text: '▎ ',
          style: lineStyle.copyWith(
            color: widget.palette.textMuted,
            fontWeight: FontWeight.w900,
          ),
        ));
        line = line.substring(4);
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

      _inline(line, lineStyle, spans, emojiDisplaySize, emojiFetchSize,
          unicodeEmojiFont);
      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }
}
