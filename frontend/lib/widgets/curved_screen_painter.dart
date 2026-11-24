import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CurvedScreenPainter extends CustomPainter {
  final bool isDark;

  CurvedScreenPainter({this.isDark = true});

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
        radius: 0.95,
        colors: isDark
            ? [
                AppTheme.cyanAccent.withValues(alpha: 0.24),
                AppTheme.primary.withValues(alpha: 0.12),
                AppTheme.darkPrimaryContainer.withValues(alpha: 0.04),
                Colors.transparent,
              ]
            : [
                const Color(0xFF0284C7).withValues(alpha: 0.16),
                const Color(0xFF0062FF).withValues(alpha: 0.08),
                Colors.transparent,
              ],
        stops: isDark ? const [0.0, 0.35, 0.70, 1.0] : const [0.0, 0.45, 1.0],
      ).createShader(glowRect);

    final Path beamPath = Path()
      ..moveTo(size.width * 0.08, 0)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.38, size.width * 0.92, 0)
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
      ..color = (isDark ? AppTheme.cyanAccent : const Color(0xFF0284C7)).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(screenPath, screenGlowPaint);

    final Paint screenPaint = Paint()
      ..shader = (isDark
              ? const LinearGradient(
                  colors: [
                    Color(0xFF0284C7),
                    Color(0xFF38BDF8),
                    Color(0xFFFFFFFF),
                    Color(0xFF38BDF8),
                    Color(0xFF0284C7),
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                )
              : const LinearGradient(
                  colors: [
                    Color(0xFF0062FF),
                    Color(0xFF0284C7),
                    Color(0xFF60A5FA),
                    Color(0xFF0284C7),
                    Color(0xFF0062FF),
                  ],
                  stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                ))
          .createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    canvas.drawPath(screenPath, screenPaint);
  }

  @override
  bool shouldRepaint(covariant CurvedScreenPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
