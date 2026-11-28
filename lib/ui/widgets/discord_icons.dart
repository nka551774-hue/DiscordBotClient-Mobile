import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// Official Discord Clyde mark as a crisp vector path.
class DiscordClydeLogo extends StatelessWidget {
  final double size;
  final Color color;

  const DiscordClydeLogo({
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 0.78),
      painter: _ClydePainter(color),
    );
  }
}

class _ClydePainter extends CustomPainter {
  final Color color;
  const _ClydePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final body = Path()
      ..moveTo(w * 0.20, h * 0.08)
      ..quadraticBezierTo(w * 0.35, h * 0.01, w * 0.42, h * 0.06)
      ..lineTo(w * 0.44, h * 0.12)
      ..quadraticBezierTo(w * 0.50, h * 0.10, w * 0.56, h * 0.12)
      ..lineTo(w * 0.58, h * 0.06)
      ..quadraticBezierTo(w * 0.65, h * 0.01, w * 0.80, h * 0.08)
      ..quadraticBezierTo(w * 0.98, h * 0.36, w * 0.98, h * 0.74)
      ..quadraticBezierTo(w * 0.86, h * 0.96, w * 0.70, h * 0.98)
      ..lineTo(w * 0.65, h * 0.86)
      ..quadraticBezierTo(w * 0.50, h * 0.91, w * 0.35, h * 0.86)
      ..lineTo(w * 0.30, h * 0.98)
      ..quadraticBezierTo(w * 0.14, h * 0.96, w * 0.02, h * 0.74)
      ..quadraticBezierTo(w * 0.02, h * 0.36, w * 0.20, h * 0.08)
      ..close();

    final leftEye = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w * 0.35, h * 0.52),
        width: w * 0.17,
        height: h * 0.24,
      ));
    final rightEye = Path()
      ..addOval(Rect.fromCenter(
        center: Offset(w * 0.65, h * 0.52),
        width: w * 0.17,
        height: h * 0.24,
      ));

    final combined = Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.difference, body, leftEye),
      rightEye,
    );
    canvas.drawPath(combined, paint);
  }

  @override
  bool shouldRepaint(covariant _ClydePainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Exact IconEmbedSvg from aiko-chan-ai/VencordDBCPlugin/icon.svg.tsx
class DbcEmbedIcon extends StatelessWidget {
  final double size;
  final Color color;

  const DbcEmbedIcon({
    super.key,
    this.size = 20,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _DbcEmbedIconPainter(color),
    );
  }
}

class _DbcEmbedIconPainter extends CustomPainter {
  final Color color;
  const _DbcEmbedIconPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final outer = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(2 * s, 2 * s, 20 * s, 20 * s),
        Radius.circular(3 * s),
      ));

    final cutouts = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(5 * s, 6 * s, 7 * s, 2 * s),
        Radius.circular(1 * s),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(5 * s, 11 * s, 14 * s, 2 * s),
        Radius.circular(1 * s),
      ))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(5 * s, 16 * s, 14 * s, 2 * s),
        Radius.circular(1 * s),
      ));

    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, cutouts),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _DbcEmbedIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Authentic Discord Status Badge:
/// - online: solid green circle
/// - idle: yellow crescent moon
/// - dnd: red circle with dark minus bar
/// - invisible: dark circle with thick #80848E hollow grey ring (matching screenshots!)
/// Profile banner with a PNG retry (some clients fail on webp banners) and
/// the accent colour behind it while loading / on failure.
class DiscordBannerImage extends StatelessWidget {
  final String? url;
  final Color color;
  final double height;

  const DiscordBannerImage({
    super.key,
    required this.url,
    required this.color,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final u = url;
    return Container(
      height: height,
      width: double.infinity,
      color: color,
      child: u == null
          ? null
          : Image.network(
              u,
              fit: BoxFit.cover,
              width: double.infinity,
              height: height,
              errorBuilder: (_, __, ___) {
                final png = u.replaceFirst(RegExp(r'\.(webp|gif)(?=\?|$)'), '.png');
                if (png == u) return const SizedBox.shrink();
                return Image.network(
                  png,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: height,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                );
              },
            ),
    );
  }
}

class DiscordStatusBadge extends StatelessWidget {
  final String status;
  final double size;
  final Color borderColor;
  final double borderWidth;

  const DiscordStatusBadge({
    super.key,
    required this.status,
    this.size = 16,
    required this.borderColor,
    this.borderWidth = 3.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _StatusBadgePainter(
        status: status,
        borderColor: borderColor,
        borderWidth: borderWidth,
      ),
    );
  }
}

class _StatusBadgePainter extends CustomPainter {
  final String status;
  final Color borderColor;
  final double borderWidth;

  const _StatusBadgePainter({
    required this.status,
    required this.borderColor,
    required this.borderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerR = size.width / 2;
    final innerR = (outerR - borderWidth).clamp(2.0, outerR);

    // Outer cutout border
    canvas.drawCircle(center, outerR, Paint()..color = borderColor);

    switch (status) {
      case 'idle':
        final full = Path()
          ..addOval(Rect.fromCircle(center: center, radius: innerR));
        final cutout = Path()
          ..addOval(Rect.fromCircle(
            center: Offset(center.dx - innerR * 0.38, center.dy - innerR * 0.38),
            radius: innerR * 0.78,
          ));
        canvas.drawPath(
          Path.combine(PathOperation.difference, full, cutout),
          Paint()
            ..color = DiscordPalette.yellow
            ..isAntiAlias = true,
        );
        break;

      case 'dnd':
        canvas.drawCircle(
          center,
          innerR,
          Paint()
            ..color = DiscordPalette.danger
            ..isAntiAlias = true,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: center,
              width: innerR * 1.25,
              height: innerR * 0.44,
            ),
            Radius.circular(innerR * 0.22),
          ),
          Paint()..color = borderColor,
        );
        break;

      case 'invisible':
        canvas.drawCircle(
          center,
          innerR,
          Paint()
            ..color = DiscordPalette.greyStatus
            ..isAntiAlias = true,
        );
        canvas.drawCircle(
          center,
          innerR * 0.48,
          Paint()
            ..color = borderColor
            ..isAntiAlias = true,
        );
        break;

      default: // online
        canvas.drawCircle(
          center,
          innerR,
          Paint()
            ..color = DiscordPalette.green
            ..isAntiAlias = true,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _StatusBadgePainter oldDelegate) =>
      oldDelegate.status != status ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth;
}

/// Draws Discord's '#' channel icon with tiny top-right lock when channel has restricted overwrites.
class DiscordChannelHashIcon extends StatelessWidget {
  final bool locked;
  final Color color;
  final double size;

  const DiscordChannelHashIcon({
    super.key,
    required this.locked,
    required this.color,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    if (!locked) {
      return Icon(Icons.tag_rounded, size: size, color: color);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(Icons.tag_rounded, size: size, color: color),
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.all(0.8),
              decoration: const BoxDecoration(
                color: Color(0xFF14151A),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock_rounded, size: size * 0.45, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glyphs from the official iOS redesign icon set that Material has no close
/// match for, redrawn as vectors on a 24×24 grid.
enum DiscordGlyphType { apps, thread, group, chat, reaction, gift, voice }

class DiscordGlyph extends StatelessWidget {
  final DiscordGlyphType type;
  final double size;
  final Color color;

  const DiscordGlyph(
    this.type, {
    super.key,
    this.size = 24,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _GlyphPainter(type, color),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  final DiscordGlyphType type;
  final Color color;
  const _GlyphPainter(this.type, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 24;
    canvas.save();
    canvas.scale(s);
    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;
    Paint stroke(double w) => Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final clear = Paint()..blendMode = BlendMode.clear;
    const bounds = Rect.fromLTWH(-2, -2, 28, 28);

    switch (type) {
      case DiscordGlyphType.chat:
        canvas.drawCircle(const Offset(12, 11), 9.5, fill);
        canvas.drawPath(
          Path()
            ..moveTo(4, 15)
            ..lineTo(2.4, 21.6)
            ..lineTo(9, 19.6)
            ..close(),
          fill,
        );
      case DiscordGlyphType.voice:
        canvas.drawRRect(
            RRect.fromLTRBR(2.5, 8.6, 7.5, 15.4, const Radius.circular(1.2)),
            fill);
        final cone = Path()
          ..moveTo(6.5, 8.6)
          ..lineTo(12.6, 4)
          ..lineTo(12.6, 20)
          ..lineTo(6.5, 15.4)
          ..close();
        canvas.drawPath(cone, fill);
        canvas.drawPath(cone, stroke(1.2));
        const c = Offset(12.6, 12);
        canvas.drawArc(Rect.fromCircle(center: c, radius: 4.2), -0.9, 1.8,
            false, stroke(2.2));
        canvas.drawArc(Rect.fromCircle(center: c, radius: 8.2), -0.95, 1.9,
            false, stroke(2.2));
      case DiscordGlyphType.thread:
        // Thread spool: parallel diagonal bars, the middle ones longest.
        const lens = [3.2, 5.2, 5.2, 3.2];
        for (var i = 0; i < 4; i++) {
          final k = (i - 1.5) * 3.6;
          final cx = 12 + k * 0.7071, cy = 12 + k * 0.7071;
          final l = lens[i];
          canvas.drawLine(Offset(cx - l * 0.7071, cy + l * 0.7071),
              Offset(cx + l * 0.7071, cy - l * 0.7071), stroke(3));
        }
      case DiscordGlyphType.group:
        canvas.saveLayer(bounds, Paint());
        canvas.drawCircle(const Offset(17, 6.6), 3.3, fill);
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(13.5, 11.4, 22.5, 18,
              topLeft: const Radius.circular(4.5),
              topRight: const Radius.circular(4.5),
              bottomLeft: const Radius.circular(1.5),
              bottomRight: const Radius.circular(1.5)),
          fill,
        );
        // Gap around the front person.
        canvas.drawCircle(const Offset(9, 8.6), 5.8, clear);
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(0.2, 11.8, 17.8, 23,
              topLeft: const Radius.circular(8.5),
              topRight: const Radius.circular(8.5)),
          clear,
        );
        canvas.drawCircle(const Offset(9, 8.6), 4.1, fill);
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(2, 13.6, 16, 21.2,
              topLeft: const Radius.circular(7),
              topRight: const Radius.circular(7),
              bottomLeft: const Radius.circular(1.5),
              bottomRight: const Radius.circular(1.5)),
          fill,
        );
        canvas.restore();
      case DiscordGlyphType.reaction:
        canvas.saveLayer(bounds, Paint());
        canvas.drawCircle(const Offset(12, 12), 10, fill);
        canvas.drawCircle(const Offset(8.7, 10), 1.45, clear);
        canvas.drawCircle(const Offset(15.3, 10), 1.45, clear);
        canvas.drawArc(
          Rect.fromCircle(center: const Offset(12, 12.4), radius: 4.6),
          0.5,
          2.14,
          false,
          Paint()
            ..blendMode = BlendMode.clear
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
        canvas.restore();
      case DiscordGlyphType.gift:
        canvas.saveLayer(bounds, Paint());
        canvas.drawRRect(
            RRect.fromLTRBR(2.6, 7.6, 21.4, 11.8, const Radius.circular(1.4)),
            fill);
        canvas.drawRRect(
          RRect.fromLTRBAndCorners(4.2, 12.9, 19.8, 21.4,
              bottomLeft: const Radius.circular(1.6),
              bottomRight: const Radius.circular(1.6)),
          fill,
        );
        canvas.drawRect(const Rect.fromLTRB(11.1, 7, 12.9, 22), clear);
        canvas.restore();
        final bow = stroke(2);
        canvas.drawPath(
          Path()
            ..moveTo(11.6, 6.8)
            ..cubicTo(9.6, 2.2, 5.2, 3.2, 6.4, 5.6)
            ..cubicTo(7.2, 7, 10, 6.9, 11.6, 6.8),
          bow,
        );
        canvas.drawPath(
          Path()
            ..moveTo(12.4, 6.8)
            ..cubicTo(14.4, 2.2, 18.8, 3.2, 17.6, 5.6)
            ..cubicTo(16.8, 7, 14, 6.9, 12.4, 6.8),
          bow,
        );
      case DiscordGlyphType.apps:
        canvas.drawRRect(
            RRect.fromLTRBR(2.5, 2.5, 10.5, 10.5, const Radius.circular(2.6)),
            fill);
        final tri = Path()
          ..moveTo(17.5, 3)
          ..lineTo(21.6, 10)
          ..lineTo(13.4, 10)
          ..close();
        canvas.drawPath(tri, fill);
        canvas.drawPath(tri, stroke(1.6));
        const b = Offset(6.5, 17.5);
        canvas.drawCircle(b, 3.5, fill);
        for (var i = 0; i < 8; i++) {
          final a = i * math.pi / 4;
          canvas.drawCircle(
              b + Offset(3.3 * math.cos(a), 3.3 * math.sin(a)), 1.5, fill);
        }
        canvas.drawPath(
          Path()
            ..moveTo(17.5, 12.6)
            ..quadraticBezierTo(18.3, 16.7, 22.4, 17.5)
            ..quadraticBezierTo(18.3, 18.3, 17.5, 22.4)
            ..quadraticBezierTo(16.7, 18.3, 12.6, 17.5)
            ..quadraticBezierTo(16.7, 16.7, 17.5, 12.6)
            ..close(),
          fill,
        );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter old) =>
      old.type != type || old.color != color;
}

/// Official empty state: illustration disc, bold title, muted body.
class DiscordEmptyState extends StatelessWidget {
  final Widget icon;
  final String title;
  final String? body;

  const DiscordEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
  });

  @override
  Widget build(BuildContext context) {
    final p = DiscordPalette(
        oled: Theme.of(context).scaffoldBackgroundColor == Colors.black);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.elevatedBg,
                shape: BoxShape.circle,
              ),
              child: IconTheme(
                data: IconThemeData(color: p.textMuted, size: 44),
                child: icon,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: p.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (body != null) ...[
              const SizedBox(height: 6),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: TextStyle(color: p.textMuted, fontSize: 14, height: 1.35),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Official Server Tag pill (badge + up to 4 characters) shown next to names.
class DiscordGuildTagPill extends StatelessWidget {
  final String tag;
  final String? badgeUrl;
  final double fontSize;

  const DiscordGuildTagPill({
    super.key,
    required this.tag,
    this.badgeUrl,
    this.fontSize = 11.5,
  });

  @override
  Widget build(BuildContext context) {
    final icon = fontSize + 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badgeUrl != null) ...[
            Image.network(
              badgeUrl!,
              width: icon,
              height: icon,
              cacheWidth: 32,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            tag,
            style: TextStyle(
              color: const Color(0xFFDBDEE1),
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge icon from Discord's CDN (PNG badge-icons, or SVG content assets).
class DiscordBadgeIcon extends StatelessWidget {
  final String url;
  final double size;

  const DiscordBadgeIcon(this.url, {super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    if (url.endsWith('.svg')) {
      return SvgPicture.network(url, width: size, height: size);
    }
    return Image.network(
      url,
      width: size,
      height: size,
      cacheWidth: (size * 2).round(),
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
