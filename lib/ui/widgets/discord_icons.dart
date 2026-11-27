import 'package:flutter/material.dart';

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
