import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// 1. SPLIT + BLUR TEXT  (React Bits: Split Text + Blur Text)
//    Letters animate in staggered with a blur-to-sharp reveal.
// ─────────────────────────────────────────────────────────────────────────────
class SplitBlurText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Duration delay;
  final Duration stagger;

  const SplitBlurText({
    super.key,
    required this.text,
    required this.style,
    this.delay = Duration.zero,
    this.stagger = const Duration(milliseconds: 60),
  });

  @override
  State<SplitBlurText> createState() => _SplitBlurTextState();
}

class _SplitBlurTextState extends State<SplitBlurText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<Animation<double>> _opacities;
  late List<Animation<double>> _blurs;
  late List<Animation<Offset>> _slides;

  @override
  void initState() {
    super.initState();
    final chars = widget.text.length;
    final totalMs = widget.delay.inMilliseconds +
        chars * widget.stagger.inMilliseconds +
        400;

    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    );

    _opacities = [];
    _blurs = [];
    _slides = [];

    for (int i = 0; i < chars; i++) {
      final start =
          (widget.delay.inMilliseconds + i * widget.stagger.inMilliseconds) /
              totalMs;
      final end = (start + 350 / totalMs).clamp(0.0, 1.0);

      final interval = CurvedAnimation(
        parent: _ctrl,
        curve: Interval(start, end, curve: Curves.easeOut),
      );

      _opacities.add(Tween<double>(begin: 0, end: 1).animate(interval));
      _blurs.add(Tween<double>(begin: 8, end: 0).animate(interval));
      _slides.add(
        Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
            .animate(interval),
      );
    }

    Future.delayed(Duration.zero, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Text.rich(
          TextSpan(
            children: List.generate(widget.text.length, (i) {
              final char = widget.text[i];
              return WidgetSpan(
                alignment: PlaceholderAlignment.baseline,
                baseline: TextBaseline.alphabetic,
                child: SlideTransition(
                  position: _slides[i],
                  child: Opacity(
                    opacity: _opacities[i].value,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(
                        sigmaX: _blurs[i].value,
                        sigmaY: _blurs[i].value,
                      ),
                      child: Text(char, style: widget.style),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SHINY TEXT  (React Bits: Shiny Text)
//    A sweeping light sheen that travels across text.
// ─────────────────────────────────────────────────────────────────────────────
class ShinyText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color shineColor;
  final Duration period;

  const ShinyText({
    super.key,
    required this.text,
    required this.style,
    this.shineColor = Colors.white,
    this.period = const Duration(seconds: 3),
  });

  @override
  State<ShinyText> createState() => _ShinyTextState();
}

class _ShinyTextState extends State<ShinyText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _sweep;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.period)..repeat();
    _sweep = Tween<double>(begin: -0.3, end: 1.3).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sweep,
      builder: (_, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final center = _sweep.value;
            return LinearGradient(
              begin: Alignment(center - 0.4, 0),
              end: Alignment(center + 0.4, 0),
              colors: [
                Colors.transparent,
                widget.shineColor.withValues(alpha: 0.55),
                widget.shineColor.withValues(alpha: 0.9),
                widget.shineColor.withValues(alpha: 0.55),
                Colors.transparent,
              ],
              stops: const [0, 0.3, 0.5, 0.7, 1],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(widget.text, style: widget.style),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. GRADIENT TEXT  (React Bits: Gradient Text)
//    Living animated gradient inside text.
// ─────────────────────────────────────────────────────────────────────────────
class GradientText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final List<Color> colors;

  const GradientText({
    super.key,
    required this.text,
    required this.style,
    required this.colors,
  });

  @override
  State<GradientText> createState() => _GradientTextState();
}

class _GradientTextState extends State<GradientText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final t = _ctrl.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(
                  math.cos(t * 2 * math.pi), math.sin(t * 2 * math.pi)),
              end: Alignment(
                  -math.cos(t * 2 * math.pi), -math.sin(t * 2 * math.pi)),
              colors: widget.colors,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(widget.text, style: widget.style.copyWith(color: Colors.white)),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. AURORA BACKGROUND  (React Bits: Soft Aurora)
//    Animated flowing gradient mesh background.
// ─────────────────────────────────────────────────────────────────────────────
class AuroraBackground extends StatefulWidget {
  final Widget child;
  final List<Color> colors;

  const AuroraBackground({
    super.key,
    required this.child,
    required this.colors,
  });

  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        return CustomPaint(
          painter: _AuroraPainter(_ctrl.value, widget.colors),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final List<Color> colors;

  _AuroraPainter(this.t, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final blobs = <_AuroraBlob>[
      _AuroraBlob(0.2, 0.15, 0.55, 0.4, colors[0 % colors.length]),
      _AuroraBlob(0.7, 0.25, 0.45, 0.35, colors[1 % colors.length]),
      _AuroraBlob(0.45, 0.60, 0.60, 0.5, colors[2 % colors.length]),
      if (colors.length > 3) _AuroraBlob(0.1, 0.7, 0.4, 0.35, colors[3]),
    ];

    for (int i = 0; i < blobs.length; i++) {
      final b = blobs[i];
      final phase = t * 2 * math.pi + i * 1.2;
      final cx = (b.cx + math.sin(phase * 0.7) * 0.12) * size.width;
      final cy = (b.cy + math.cos(phase * 0.5) * 0.1) * size.height;
      final rx = b.rx * size.width;
      final ry = b.ry * size.height;

      final shader = RadialGradient(
        colors: [
          b.color.withValues(alpha: 0.55),
          b.color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCenter(
        center: Offset(cx, cy),
        width: rx * 2,
        height: ry * 2,
      ));

      paint.shader = shader;
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cy), width: rx * 2, height: ry * 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_AuroraPainter old) => old.t != t;
}

class _AuroraBlob {
  final double cx, cy, rx, ry;
  final Color color;
  const _AuroraBlob(this.cx, this.cy, this.rx, this.ry, this.color);
}

// ─────────────────────────────────────────────────────────────────────────────
// 5. PARTICLE OVERLAY  (React Bits: Particles)
//    Drifting particles overlay on hero banner.
// ─────────────────────────────────────────────────────────────────────────────
class ParticleOverlay extends StatefulWidget {
  final Widget child;
  final int count;
  final Color color;

  const ParticleOverlay({
    super.key,
    required this.child,
    this.count = 35,
    this.color = Colors.white,
  });

  @override
  State<ParticleOverlay> createState() => _ParticleOverlayState();
}

class _ParticleOverlayState extends State<ParticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(widget.count, (_) => _Particle(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ParticlePainter(
                    _ctrl.value,
                    _particles,
                    widget.color,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _Particle {
  final double x, y, size, speed, phase;
  _Particle(math.Random rng)
      : x = rng.nextDouble(),
        y = rng.nextDouble(),
        size = rng.nextDouble() * 2.5 + 0.8,
        speed = rng.nextDouble() * 0.4 + 0.1,
        phase = rng.nextDouble() * math.pi * 2;
}

class _ParticlePainter extends CustomPainter {
  final double t;
  final List<_Particle> particles;
  final Color color;

  _ParticlePainter(this.t, this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final tx =
          (p.x + math.sin(t * 2 * math.pi * p.speed + p.phase) * 0.04) % 1.0;
      final ty = (p.y - t * p.speed * 0.3) % 1.0;
      final opacity =
          (0.3 + 0.5 * math.sin(t * 2 * math.pi * p.speed + p.phase + 1))
              .clamp(0.05, 0.85);

      canvas.drawCircle(
        Offset(tx * size.width, ty * size.height),
        p.size,
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlePainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// 6. TILTED CARD  (React Bits: Tilted Card)
//    3D perspective tilt on hover/pointer movement.
// ─────────────────────────────────────────────────────────────────────────────
class TiltedCard extends StatefulWidget {
  final Widget child;
  final double maxTilt;
  final double scale;

  const TiltedCard({
    super.key,
    required this.child,
    this.maxTilt = 8.0,
    this.scale = 1.03,
  });

  @override
  State<TiltedCard> createState() => _TiltedCardState();
}

class _TiltedCardState extends State<TiltedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _tiltX;
  late Animation<double> _tiltY;
  bool _hovering = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _tiltX =
        Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _tiltY =
        Tween<double>(begin: 0, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onHover(PointerEvent event, Size size) {
    final dx = (event.localPosition.dx / size.width - 0.5) * 2;
    final dy = (event.localPosition.dy / size.height - 0.5) * 2;
    final targetX = dy * widget.maxTilt;
    final targetY = -dx * widget.maxTilt;

    final prevX = _tiltX.value;
    final prevY = _tiltY.value;
    _tiltX = Tween<double>(begin: prevX, end: targetX)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _tiltY = Tween<double>(begin: prevY, end: targetY)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward(from: 0);
  }

  void _onExit() {
    final prevX = _tiltX.value;
    final prevY = _tiltY.value;
    _tiltX = Tween<double>(begin: prevX, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _tiltY = Tween<double>(begin: prevY, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward(from: 0);
    setState(() => _hovering = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      return MouseRegion(
        onHover: (e) {
          setState(() => _hovering = true);
          _onHover(e, size);
        },
        onExit: (_) => _onExit(),
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(_tiltX.value * math.pi / 180)
                ..rotateY(_tiltY.value * math.pi / 180)
                ..scaleByDouble(
                  _hovering ? widget.scale : 1.0,
                  _hovering ? widget.scale : 1.0,
                  1.0,
                  1.0,
                ),
              child: child,
            );
          },
          child: widget.child,
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 7. SPOTLIGHT CARD  (React Bits: Spotlight Card)
//    Glowing touch/pointer-tracked spotlight on a card.
// ─────────────────────────────────────────────────────────────────────────────
class SpotlightCard extends StatefulWidget {
  final Widget child;
  final Color spotColor;
  final double spotRadius;
  final double spotOpacity;
  final BorderRadius borderRadius;

  const SpotlightCard({
    super.key,
    required this.child,
    this.spotColor = const Color(0xFF60A5FA),
    this.spotRadius = 120,
    this.spotOpacity = 0.18,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  @override
  State<SpotlightCard> createState() => _SpotlightCardState();
}

class _SpotlightCardState extends State<SpotlightCard>
    with SingleTickerProviderStateMixin {
  Offset? _spotPos;
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _opacity = Tween<double>(begin: 0, end: 1).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (e) {
        setState(() => _spotPos = e.localPosition);
        _ctrl.forward();
      },
      onExit: (_) {
        _ctrl.reverse();
        setState(() => _spotPos = null);
      },
      child: GestureDetector(
        onPanUpdate: (e) => setState(() => _spotPos = e.localPosition),
        child: ClipRRect(
          borderRadius: widget.borderRadius,
          child: AnimatedBuilder(
            animation: _opacity,
            builder: (_, child) {
              return Stack(
                children: [
                  child!,
                  if (_spotPos != null && _opacity.value > 0)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: CustomPaint(
                          painter: _SpotlightPainter(
                            _spotPos!,
                            widget.spotColor,
                            widget.spotRadius,
                            widget.spotOpacity * _opacity.value,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Offset center;
  final Color color;
  final double radius;
  final double opacity;

  _SpotlightPainter(this.center, this.color, this.radius, this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.center != center || old.opacity != opacity;
}

// ─────────────────────────────────────────────────────────────────────────────
// 8. BORDER GLOW  (React Bits: Border Glow)
//    Pulsing glow border for selected seats.
// ─────────────────────────────────────────────────────────────────────────────
class BorderGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final BorderRadius borderRadius;
  final bool active;

  const BorderGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
    this.active = true,
  });

  @override
  State<BorderGlow> createState() => _BorderGlowState();
}

class _BorderGlowState extends State<BorderGlow>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (_, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withValues(alpha: _pulse.value * 0.75),
                blurRadius: 12 * _pulse.value,
                spreadRadius: 1.5 * _pulse.value,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 9. PIXEL BURST  (React Bits: Pixel Card tap effect)
//    Particle burst animation on seat tap.
// ─────────────────────────────────────────────────────────────────────────────
class PixelBurst extends StatefulWidget {
  final Color color;
  final double size;
  final VoidCallback onComplete;

  const PixelBurst({
    super.key,
    required this.color,
    this.size = 40,
    required this.onComplete,
  });

  @override
  State<PixelBurst> createState() => _PixelBurstState();
}

class _PixelBurstState extends State<PixelBurst>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late List<_BurstParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(12, (_) => _BurstParticle(rng));
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )
      ..forward()
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _BurstPainter(_ctrl.value, _particles, widget.color),
        );
      },
    );
  }
}

class _BurstParticle {
  final double angle, speed, size;
  _BurstParticle(math.Random rng)
      : angle = rng.nextDouble() * 2 * math.pi,
        speed = rng.nextDouble() * 0.4 + 0.3,
        size = rng.nextDouble() * 2.5 + 1.5;
}

class _BurstPainter extends CustomPainter {
  final double t;
  final List<_BurstParticle> particles;
  final Color color;

  _BurstPainter(this.t, this.particles, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxR = size.width / 2;
    final eased = Curves.easeOut.transform(t);

    for (final p in particles) {
      final r = maxR * p.speed * eased;
      final x = center.dx + math.cos(p.angle) * r;
      final y = center.dy + math.sin(p.angle) * r;
      final opacity = (1 - eased).clamp(0.0, 1.0);
      canvas.drawCircle(
        Offset(x, y),
        p.size * (1 - eased * 0.5),
        Paint()..color = color.withValues(alpha: opacity),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

// ─────────────────────────────────────────────────────────────────────────────
// 10. COUNT UP TEXT  (React Bits: Count Up)
//     Animated number counter that rolls to a new value.
// ─────────────────────────────────────────────────────────────────────────────
class CountUpText extends StatefulWidget {
  final double value;
  final String prefix;
  final String suffix;
  final int decimals;
  final TextStyle style;
  final Duration duration;

  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.decimals = 2,
    required this.style,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<CountUpText> createState() => _CountUpTextState();
}

class _CountUpTextState extends State<CountUpText>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);
    _anim = Tween<double>(begin: 0, end: widget.value).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(CountUpText old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final prev = _anim.value;
      _anim = Tween<double>(begin: prev, end: widget.value).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
      );
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        final formatted = widget.decimals > 0
            ? _anim.value.toStringAsFixed(widget.decimals)
            : _anim.value.toInt().toString();
        return Text(
          '${widget.prefix}$formatted${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 11. PARALLAX WIDGET  (React Bits: Scroll Float)
//     Applies a scroll-driven parallax translation to any widget.
// ─────────────────────────────────────────────────────────────────────────────
class ParallaxWidget extends StatefulWidget {
  final Widget child;
  final double factor;

  const ParallaxWidget({
    super.key,
    required this.child,
    this.factor = 0.3,
  });

  @override
  State<ParallaxWidget> createState() => _ParallaxWidgetState();
}

class _ParallaxWidgetState extends State<ParallaxWidget> {
  final GlobalKey _key = GlobalKey();
  double _offset = 0;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          final pos = box.localToGlobal(Offset.zero);
          final screenH = MediaQuery.of(context).size.height;
          final relY = (pos.dy / screenH - 0.5);
          if (mounted) setState(() => _offset = relY * widget.factor * 80);
        }
        return false;
      },
      child: Transform.translate(
        key: _key,
        offset: Offset(0, _offset),
        child: widget.child,
      ),
    );
  }
}
