import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/discord_models.dart';
import '../theme/app_theme.dart';
import 'discord_markdown.dart';
import 'media_viewer.dart';

/// Renders a message's raw `components` tree: classic action rows (buttons /
/// selects) and Components V2 (container, text display, section, thumbnail,
/// media gallery, file, separator) the way the official client draws them.
class DiscordComponentsView extends StatelessWidget {
  final List<dynamic> components;
  final List<DiscordAttachment> attachments;
  final DiscordPalette palette;
  final DiscordGuild? guild;
  final bool ecoMode;
  final bool alwaysAnimate;
  final void Function(List<MediaViewerItem> items, int index) onOpenMedia;

  const DiscordComponentsView({
    super.key,
    required this.components,
    required this.attachments,
    required this.palette,
    this.guild,
    required this.ecoMode,
    this.alwaysAnimate = false,
    required this.onOpenMedia,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final c in components)
          if (c is Map) _node(context, c),
      ],
    );
  }

  DiscordAttachment? _attachmentFor(String url) {
    if (!url.startsWith('attachment://')) return null;
    final name = url.substring('attachment://'.length);
    for (final a in attachments) {
      if (a.filename == name) return a;
    }
    return null;
  }

  String? _mediaUrl(dynamic media) {
    if (media is! Map) return null;
    final url = (media['proxy_url'] ?? media['url'])?.toString();
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('attachment://')) {
      final a = _attachmentFor(url);
      if (a == null) return null;
      return a.isImage ? a.previewUrl(maxWidth: 800) : a.url;
    }
    return url;
  }

  List<Map> _children(Map c) =>
      (c['components'] as List?)?.whereType<Map>().toList() ?? const <Map>[];

  Widget _node(BuildContext context, Map c) {
    final type = (c['type'] as num?)?.toInt() ?? 0;
    switch (type) {
      case 1: // Action row
        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final k in _children(c)) _node(context, k)],
          ),
        );
      case 2:
        return _button(c);
      case 3:
      case 5:
      case 6:
      case 7:
      case 8:
        return _select(c);
      case 9: // Section: text on the left, accessory on the right
        final accessory = c['accessory'];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final k in _children(c)) _node(context, k)],
                ),
              ),
              if (accessory is Map)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: _node(context, accessory),
                ),
            ],
          ),
        );
      case 10: // Text display
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: DiscordMarkdownView(
            text: c['content']?.toString() ?? '',
            palette: palette,
            guild: guild,
            ecoMode: ecoMode,
            alwaysAnimate: alwaysAnimate,
            fontSize: 14.5,
          ),
        );
      case 11: // Thumbnail
        final url = _mediaUrl(c['media']);
        if (url == null) return const SizedBox.shrink();
        return GestureDetector(
          onTap: () => onOpenMedia([MediaViewerItem(url)], 0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              width: 84,
              height: 84,
              cacheWidth: 168,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 84, height: 84, color: palette.elevatedBg),
            ),
          ),
        );
      case 12: // Media gallery
        final urls = <String>[
          for (final it in (c['items'] as List?) ?? const [])
            if (it is Map && _mediaUrl(it['media']) != null)
              _mediaUrl(it['media'])!,
        ];
        return _gallery(urls);
      case 13: // File
        final raw = (c['file'] is Map)
            ? ((c['file'] as Map)['url']?.toString() ?? '')
            : '';
        final att = _attachmentFor(raw);
        return _fileCard(
          att?.filename ?? raw.replaceFirst('attachment://', ''),
          att?.formattedSize,
          att?.url ?? raw,
        );
      case 14: // Separator
        final big = (c['spacing'] as num?)?.toInt() == 2;
        final divider = c['divider'] != false;
        return Padding(
          padding: EdgeInsets.symmetric(vertical: big ? 12 : 6),
          child: divider
              ? Divider(height: 1, color: palette.border)
              : const SizedBox.shrink(),
        );
      case 17: // Container
        final accent = (c['accent_color'] as num?)?.toInt();
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: palette.cardBg,
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: accent != null
                  ? BorderSide(color: Color(0xFF000000 | accent), width: 4)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final k in _children(c)) _node(context, k)],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _gallery(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    final items = [for (final u in urls) MediaViewerItem(u)];
    Widget tile(int i) => GestureDetector(
          onTap: () => onOpenMedia(items, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              urls[i],
              width: double.infinity,
              fit: BoxFit.cover,
              cacheWidth: 600,
              errorBuilder: (_, __, ___) =>
                  Container(height: 120, color: palette.elevatedBg),
            ),
          ),
        );
    if (urls.length == 1) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300, maxWidth: 430),
          child: tile(0),
        ),
      );
    }
    final cols = (urls.length == 2 || urls.length == 4) ? 2 : 3;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: GridView.count(
          crossAxisCount: cols,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          children: [for (var i = 0; i < urls.length; i++) tile(i)],
        ),
      ),
    );
  }

  Widget _fileCard(String name, String? size, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () {
          final uri = Uri.tryParse(url);
          if (uri != null) {
            launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: palette.elevatedBg,
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
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF00A8FC),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (size != null)
                      Text(size,
                          style:
                              TextStyle(color: palette.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(Map c) {
    final style = (c['style'] as num?)?.toInt() ?? 2;
    final disabled = c['disabled'] == true;
    final label = c['label']?.toString();
    final url = c['url']?.toString();
    final emoji = c['emoji'];
    final bg = switch (style) {
      1 => DiscordPalette.blurple,
      3 => const Color(0xFF248046),
      4 => const Color(0xFFDA373C),
      _ => const Color(0xFF4E5058),
    };
    Widget? emojiWidget;
    if (emoji is Map) {
      final id = emoji['id']?.toString();
      if (id != null && id.isNotEmpty) {
        final ext = emoji['animated'] == true ? 'gif' : 'webp';
        emojiWidget = Image.network(
          'https://cdn.discordapp.com/emojis/$id.$ext?size=48',
          width: 18,
          height: 18,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        );
      } else {
        emojiWidget = Text(emoji['name']?.toString() ?? '',
            style: const TextStyle(fontSize: 16));
      }
    }
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: (url != null && !disabled)
              ? () {
                  final uri = Uri.tryParse(url);
                  if (uri != null) {
                    launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emojiWidget != null) emojiWidget,
                if (emojiWidget != null && label != null)
                  const SizedBox(width: 6),
                if (label != null)
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (style == 5) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.open_in_new_rounded,
                      size: 14, color: Colors.white),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _select(Map c) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.elevatedBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              c['placeholder']?.toString() ?? '選擇一個選項',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: palette.textMuted, fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.expand_more_rounded, color: palette.textMuted, size: 20),
        ],
      ),
    );
  }
}
