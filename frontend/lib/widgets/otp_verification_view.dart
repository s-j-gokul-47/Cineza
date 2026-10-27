import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

enum OtpPhase { idle, typing, verifying, success, error }

class OtpVerificationView extends StatefulWidget {
  final int length;
  final Future<bool> Function(String code) onVerify;
  final VoidCallback onSuccess;
  final VoidCallback onResend;
  final VoidCallback? onCancel;
  final String title;
  final String subtitle;
  final String successTitle;
  final String successSubtitle;
  final String errorTitle;
  final String defaultErrorSubtitle;
  final bool showCancelOnlyOnError;

  const OtpVerificationView({
    super.key,
    this.length = 4,
    required this.onVerify,
    required this.onSuccess,
    required this.onResend,
    this.onCancel,
    this.showCancelOnlyOnError = true,
    this.title = "Let's verify your number",
    this.subtitle = "We've sent a 4-digit code to your phone.",
    this.successTitle = "Verified successfully",
    this.successSubtitle = "Your phone number has been verified.",
    this.errorTitle = "Invalid code",
    this.defaultErrorSubtitle = "The code you entered is incorrect. Please try again.",
  });

  @override
  State<OtpVerificationView> createState() => _OtpVerificationViewState();
}

class _OtpVerificationViewState extends State<OtpVerificationView>
    with TickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _code = "";
  OtpPhase _phase = OtpPhase.idle;
  String _customError = "";
  final List<Timer> _timers = [];
  bool _hasVerificationFailed = false;

  // Animation Controllers
  late AnimationController _shakeController;
  late AnimationController _checkController;
  late AnimationController _pulseController;
  late AnimationController _caretController;

  // Caret blinking
  bool _showCaret = true;

  @override
  void initState() {
    super.initState();

    // Shake controller for error phase
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Checkmark draw-in controller
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    // Ripple pulse for checkmark
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // Blinking cursor
    _caretController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _showCaret = !_showCaret);
          _caretController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          setState(() => _showCaret = !_showCaret);
          _caretController.forward();
        }
      });
    _caretController.forward();

    // Auto-focus text field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  void _clearTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  void _addTimer(VoidCallback fn, int ms) {
    _timers.add(Timer(Duration(milliseconds: ms), fn));
  }

  @override
  void dispose() {
    _clearTimers();
    _shakeController.dispose();
    _checkController.dispose();
    _pulseController.dispose();
    _caretController.dispose();
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleInput(String val) {
    if (_phase == OtpPhase.verifying ||
        _phase == OtpPhase.success ||
        _phase == OtpPhase.error) {
      return;
    }

    final digitsOnly = val.replaceAll(RegExp(r'\D'), '');
    final trimmed = digitsOnly.length > widget.length
        ? digitsOnly.substring(0, widget.length)
        : digitsOnly;

    setState(() {
      _code = trimmed;
      _phase = trimmed.isNotEmpty ? OtpPhase.typing : OtpPhase.idle;
    });

    if (trimmed.length == widget.length) {
      _triggerVerification(trimmed);
    }
  }

  void _triggerVerification(String codeToVerify) {
    _clearTimers();

    // 1. Brief pause (300ms) so user sees all digits entered
    _addTimer(() {
      if (!mounted) return;
      setState(() => _phase = OtpPhase.verifying);
    }, 300);

    // 2. Scan sweep (800ms) then execute real verification
    _addTimer(() async {
      if (!mounted) return;
      try {
        final isValid = await widget.onVerify(codeToVerify);

        if (!mounted) return;

        if (isValid) {
          setState(() {
            _phase = OtpPhase.success;
          });

          _pulseController.forward(from: 0);
          _checkController.forward(from: 0);

          // Success hold before triggering parent onSuccess (800ms for smooth feedback)
          _addTimer(() {
            if (mounted) {
              widget.onSuccess();
            }
          }, 800);
        } else {
          _triggerErrorState('Invalid OTP code.');
        }
      } catch (e) {
        _triggerErrorState(e.toString().replaceFirst('Exception: ', ''));
      }
    }, 1100);
  }

  void _triggerErrorState(String message) {
    if (!mounted) return;
    setState(() {
      _phase = OtpPhase.error;
      _customError = message;
      _hasVerificationFailed = true;
    });

    _shakeController.forward(from: 0);

    // Hold error shake, then clear and reset
    _addTimer(() {
      if (mounted) {
        setState(() {
          _code = "";
          _inputController.clear();
          _customError = "";
          _phase = OtpPhase.idle;
        });
        _focusNode.requestFocus();
      }
    }, 1400);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.isDark(context);
    final activeIndex = math.min(_code.length, widget.length - 1);
    final isError = _phase == OtpPhase.error;
    final isSuccess = _phase == OtpPhase.success;

    final containerBg = isDark ? const Color(0xFF141722) : Colors.white;
    final containerBorder = isSuccess
        ? const Color(0xFF34D399).withValues(alpha: 0.6)
        : isError
            ? const Color(0xFFEF4444).withValues(alpha: 0.6)
            : (isDark ? const Color(0xFF262B40) : const Color(0xFFE2E8F0));

    return GestureDetector(
      onTap: () => _focusNode.requestFocus(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
        decoration: BoxDecoration(
          color: containerBg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: containerBorder,
            width: 1.2,
          ),
          boxShadow: [
            if (isSuccess)
              BoxShadow(
                color: const Color(0xFF34D399).withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 10),
              )
            else if (isError)
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 10),
              )
            else
              BoxShadow(
                color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient Radial Background Glow
            if (isSuccess)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF34D399).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            if (isError)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFEF4444).withValues(alpha: 0.18),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Heading Slot with Crossfade
                _buildHeadingSlot(isSuccess, isError, isDark),
                const SizedBox(height: 24),

                // 2. Hidden Real Keystroke Input + Animated Boxes / Checkmark
                _buildBodySlot(activeIndex, isSuccess, isError, isDark),
                const SizedBox(height: 24),

                // 3. Footer with Resend & Change Phone actions
                _buildFooter(isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- HEADING SLOT ---

  Widget _buildHeadingSlot(bool isSuccess, bool isError, bool isDark) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Column(
        key: ValueKey<String>('$_phase-$_customError'),
        children: [
          Text(
            isSuccess
                ? widget.successTitle
                : isError
                    ? widget.errorTitle
                    : widget.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isSuccess
                  ? const Color(0xFF34D399)
                  : isError
                      ? const Color(0xFFEF4444)
                      : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isSuccess
                ? widget.successSubtitle
                : isError
                    ? (_customError.isNotEmpty
                        ? _customError
                        : widget.defaultErrorSubtitle)
                    : widget.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: isError
                  ? const Color(0xFFFCA5A5)
                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // --- BODY SLOT ---

  Widget _buildBodySlot(int activeIndex, bool isSuccess, bool isError, bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Invisible input taking actual keypresses
        if (!isSuccess)
          Opacity(
            opacity: 0,
            child: SizedBox(
              width: 1,
              height: 1,
              child: TextField(
                controller: _inputController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: widget.length,
                onChanged: _handleInput,
              ),
            ),
          ),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: !isSuccess
              ? _buildOtpRow(activeIndex, isError, isDark)
              : _buildSuccessCheckmark(),
        ),
      ],
    );
  }

  // --- OTP ROW OF BOXES ---

  Widget _buildOtpRow(int activeIndex, bool isError, bool isDark) {
    return AnimatedBuilder(
      animation: _shakeController,
      builder: (context, child) {
        double shakeX = 0;
        if (isError && _shakeController.value > 0) {
          final t = _shakeController.value;
          shakeX = math.sin(t * math.pi * 5) * 12 * (1 - t);
        }

        return Transform.translate(
          offset: Offset(shakeX, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (i) {
              final isFilled = i < _code.length;
              final digit = isFilled ? _code[i] : "";
              final isActive = i == activeIndex && _phase != OtpPhase.verifying;
              final isVerifying = _phase == OtpPhase.verifying;

              final boxPadding = widget.length <= 4 ? 7.0 : 4.0;
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: boxPadding),
                child: _buildOtpBox(
                  index: i,
                  digit: digit,
                  isFilled: isFilled,
                  isActive: isActive,
                  isVerifying: isVerifying,
                  isError: isError,
                  isDark: isDark,
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildOtpBox({
    required int index,
    required String digit,
    required bool isFilled,
    required bool isActive,
    required bool isVerifying,
    required bool isError,
    required bool isDark,
  }) {
    Color borderColor;
    Color glowColor;
    double scale = 1.0;

    final primaryAccent = isDark ? const Color(0xFFF84464) : const Color(0xFFE11D48);

    if (isError) {
      borderColor = const Color(0xFFEF4444);
      glowColor = const Color(0xFFEF4444).withValues(alpha: 0.4);
    } else if (isVerifying) {
      borderColor = const Color(0xFF34D399);
      glowColor = const Color(0xFF34D399).withValues(alpha: 0.5);
      scale = 1.05;
    } else if (isActive) {
      borderColor = primaryAccent;
      glowColor = primaryAccent.withValues(alpha: 0.35);
    } else {
      borderColor = isDark ? const Color(0xFF262B40) : const Color(0xFFE2E8F0);
      glowColor = Colors.transparent;
    }

    final boxWidth = widget.length <= 4 ? 60.0 : 48.0;
    final boxHeight = widget.length <= 4 ? 68.0 : 58.0;
    final fontSize = widget.length <= 4 ? 26.0 : 22.0;

    final filledBg = isDark ? const Color(0xFF1E2336) : const Color(0xFFF1F5F9);
    final emptyBg = isDark ? const Color(0xFF0C0F17) : Colors.white;

    return AnimatedContainer(
      duration: Duration(milliseconds: isVerifying ? (200 + index * 60) : 200),
      curve: Curves.easeOut,
      width: boxWidth,
      height: boxHeight,
      transform: Matrix4.diagonal3Values(scale, scale, 1.0),
      transformAlignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFilled ? filledBg : emptyBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: isActive ? 2.0 : 1.4),
        boxShadow: [
          if (glowColor != Colors.transparent)
            BoxShadow(
              color: glowColor,
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Center(
        child: isFilled
            ? AnimatedScale(
                scale: 1.0,
                duration: const Duration(milliseconds: 200),
                curve: Curves.elasticOut,
                child: Text(
                  digit,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: isError
                        ? const Color(0xFFF87171)
                        : (isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A)),
                  ),
                ),
              )
            : (isActive && _showCaret)
                ? Container(
                    width: 2,
                    height: 26,
                    decoration: BoxDecoration(
                      color: primaryAccent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )
                : const SizedBox.shrink(),
      ),
    );
  }

  // --- SUCCESS CHECKMARK ---

  Widget _buildSuccessCheckmark() {
    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _checkController]),
      builder: (context, _) {
        final pulseScale = 1.0 + (_pulseController.value * 0.7);
        final pulseOpacity = (1.0 - _pulseController.value).clamp(0.0, 1.0);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Expanding Pulse Wave
            Transform.scale(
              scale: pulseScale,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: const Color(0xFF34D399).withValues(alpha: pulseOpacity * 0.6),
                    width: 2,
                  ),
                ),
              ),
            ),

            // Checkmark Box
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: const RadialGradient(
                  center: Alignment(0, -0.2),
                  colors: [Color(0xFF162D24), Color(0xFF0F1E18)],
                ),
                border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: 0.8),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34D399).withValues(alpha: 0.45),
                    blurRadius: 30,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CustomPaint(
                painter: _CheckmarkPainter(progress: _checkController.value),
              ),
            ),
          ],
        );
      },
    );
  }

  // --- FOOTER ---

  Widget _buildFooter(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Didn't receive the code? ",
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
            InkWell(
              onTap: _phase == OtpPhase.verifying ? null : widget.onResend,
              child: Text(
                'Resend',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFF84464) : const Color(0xFFE11D48),
                ),
              ),
            ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: (widget.onCancel != null &&
                  (!widget.showCancelOnlyOnError || _hasVerificationFailed))
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: InkWell(
                    onTap: widget.onCancel,
                    child: Text(
                      'Change phone number',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// Custom Painter to draw checkmark stroke matching framer-motion pathLength
class _CheckmarkPainter extends CustomPainter {
  final double progress; // 0.0 to 1.0

  _CheckmarkPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final paint = Paint()
      ..color = const Color(0xFF34D399)
      ..strokeWidth = 4.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Start at (size.width * 0.28, size.height * 0.52)
    final p1 = Offset(size.width * 0.28, size.height * 0.52);
    final p2 = Offset(size.width * 0.45, size.height * 0.68);
    final p3 = Offset(size.width * 0.74, size.height * 0.36);

    path.moveTo(p1.dx, p1.dy);
    path.lineTo(p2.dx, p2.dy);
    path.lineTo(p3.dx, p3.dy);

    // Extract subpath according to progress
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final metric = metrics.first;
    final length = metric.length;
    final extract = metric.extractPath(0.0, length * progress);

    canvas.drawPath(extract, paint);
  }

  @override
  bool shouldRepaint(covariant _CheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
