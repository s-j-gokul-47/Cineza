import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CurvedScreenPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Ambient projection beam glow
    final Rect glowRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.4),
      width: size.width * 0.9,
      height: size.height * 1.5,
    );

    final Paint beamPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 0.85,
        colors: [
          AppTheme.cyanAccent.withOpacity(0.18),
          AppTheme.primary.withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(glowRect);

    final Path beamPath = Path()
      ..moveTo(size.width * 0.1, 0)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.35, size.width * 0.9, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(beamPath, beamPaint);

    // 2. Curved screen physical bar
    final Path screenPath = Path();
    screenPath.moveTo(size.width * 0.05, size.height * 0.45);
    screenPath.quadraticBezierTo(
      size.width * 0.5,
      0,
      size.width * 0.95,
      size.height * 0.45,
    );

    final Paint screenGlowPaint = Paint()
      ..color = AppTheme.cyanAccent.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(screenPath, screenGlowPaint);

    final Paint screenPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF38BDF8),
          Color(0xFFE0F2FE),
          Color(0xFF38BDF8),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    canvas.drawPath(screenPath, screenPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
