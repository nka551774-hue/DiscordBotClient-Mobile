import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/strings.dart';

class MediaViewerItem {
  /// Image shown in the viewer.
  final String url;

  /// Original file (opened / copied from the ⋯ menu); defaults to [url].
  final String? originalUrl;

  const MediaViewerItem(this.url, {this.originalUrl});
}

/// Official-style full screen media viewer: black stage, swipe between
/// images, swipe down to dismiss, pinch / double-tap zoom, tap to hide chrome,
/// close + author header on top and a ⋯ menu.
Future<void> showDiscordMediaViewer(
  BuildContext context, {
  required List<MediaViewerItem> items,
  int initialIndex = 0,
  String? authorName,
  String? authorAvatarUrl,
  DateTime? timestamp,
}) {
  if (items.isEmpty) return Future<void>.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (_, __, ___) => _MediaViewerPage(
        items: items,
        initialIndex: initialIndex.clamp(0, items.length - 1),
        authorName: authorName,
        authorAvatarUrl: authorAvatarUrl,
        timestamp: timestamp,
      ),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class _MediaViewerPage extends StatefulWidget {
  final List<MediaViewerItem> items;
  final int initialIndex;
  final String? authorName;
  final String? authorAvatarUrl;
  final DateTime? timestamp;

  const _MediaViewerPage({
    required this.items,
    required this.initialIndex,
    this.authorName,
    this.authorAvatarUrl,
    this.timestamp,
  });

  @override
  State<_MediaViewerPage> createState() => _MediaViewerPageState();
}

class _MediaViewerPageState extends State<_MediaViewerPage> {
  late final PageController _pageCtrl;
  late final List<TransformationController> _zoomCtrls;
  late int _index;
  double _dragDy = 0;
  bool _chrome = true;
  bool _zoomed = false;
  Offset _doubleTapPos = Offset.zero;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageCtrl = PageController(initialPage: _index);
    _zoomCtrls = List.generate(widget.items.length, (_) {
      final c = TransformationController();
      c.addListener(_onZoomChanged);
      return c;
    });
  }

  @override
  void dispose() {
    for (final c in _zoomCtrls) {
      c.removeListener(_onZoomChanged);
      c.dispose();
    }
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onZoomChanged() {
    final z = _zoomCtrls[_index].value.getMaxScaleOnAxis() > 1.01;
    if (z != _zoomed) setState(() => _zoomed = z);
  }

  void _toggleDoubleTapZoom() {
    final c = _zoomCtrls[_index];
    if (_zoomed) {
      c.value = Matrix4.identity();
      return;
    }
    const scale = 2.5;
    final p = _doubleTapPos;
    c.value = Matrix4.identity()
      ..translate(-p.dx * (scale - 1), -p.dy * (scale - 1))
      ..scale(scale);
  }

  String _timeLabel(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    final now = DateTime.now();
    if (t.year == now.year && t.month == now.month && t.day == now.day) {
      return trf('今天 {0}:{1}', [hh, mm]);
    }
    return '${t.year}/${t.month}/${t.day} $hh:$mm';
  }

  void _showMore() {
    final item = widget.items[_index];
    final link = item.originalUrl ?? item.url;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF232428),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_browser_rounded,
                  color: Colors.white),
              title: Text(tr('在瀏覽器開啟 / 儲存'),
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.of(ctx).pop();
                final uri = Uri.tryParse(link);
                if (uri != null) {
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: Colors.white),
              title:
                  Text(tr('複製連結'), style: TextStyle(color: Colors.white)),
              onTap: () {
                Clipboard.setData(ClipboardData(text: link));
                Navigator.of(ctx).pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgAlpha = (255 * (1 - _dragDy.abs() / 420)).clamp(0, 255).round();
    final multi = widget.items.length > 1;

    return Scaffold(
      backgroundColor: Colors.black.withAlpha(bgAlpha),
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _chrome = !_chrome),
            onDoubleTapDown: (d) => _doubleTapPos = d.localPosition,
            onDoubleTap: _toggleDoubleTapZoom,
            onVerticalDragUpdate: _zoomed
                ? null
                : (d) => setState(() => _dragDy += d.delta.dy),
            onVerticalDragEnd: _zoomed
                ? null
                : (d) {
                    final v = d.primaryVelocity ?? 0;
                    if (_dragDy.abs() > 120 || v.abs() > 900) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() => _dragDy = 0);
                    }
                  },
            child: Transform.translate(
              offset: Offset(0, _dragDy),
              child: PageView.builder(
                controller: _pageCtrl,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                itemCount: widget.items.length,
                onPageChanged: (i) {
                  _zoomCtrls[_index].value = Matrix4.identity();
                  setState(() {
                    _index = i;
                    _zoomed = false;
                  });
                },
                itemBuilder: (_, i) => InteractiveViewer(
                  transformationController: _zoomCtrls[i],
                  minScale: 1,
                  maxScale: 5,
                  panEnabled: _zoomed,
                  child: Center(
                    child: Image.network(
                      widget.items[i].url,
                      fit: BoxFit.contain,
                      loadingBuilder: (_, child, progress) => progress == null
                          ? child
                          : const CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.broken_image_outlined,
                        color: Colors.white54,
                        size: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Top chrome: close, author + time, ⋯
          AnimatedOpacity(
            opacity: (_chrome && _dragDy == 0) ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: !_chrome,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xAA000000), Color(0x00000000)],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 16),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 26),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (widget.authorAvatarUrl != null) ...[
                          CircleAvatar(
                            radius: 15,
                            backgroundImage:
                                NetworkImage(widget.authorAvatarUrl!),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (widget.authorName != null)
                                Text(
                                  widget.authorName!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              if (widget.timestamp != null || multi)
                                Text(
                                  [
                                    if (widget.timestamp != null)
                                      _timeLabel(widget.timestamp!),
                                    if (multi)
                                      '${_index + 1} / ${widget.items.length}',
                                  ].join('  •  '),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_horiz_rounded,
                              color: Colors.white, size: 26),
                          onPressed: _showMore,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
