import 'package:flutter/material.dart';

/// Draws the official Discord Clyde mark cleanly as a vector path.
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
