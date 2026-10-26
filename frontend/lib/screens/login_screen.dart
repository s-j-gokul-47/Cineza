import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/login_js_helper.dart';
import '../widgets/otp_verification_view.dart';
import 'terms_policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();

  // Mobile Controller & OTP State
  final TextEditingController _phoneController = TextEditingController();
  bool _otpSent = false;
  String? _reqId;
  String? _pendingAccessToken;
  Timer? _timeoutTimer;

  // Loading & Feedback
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isOtpLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Design Tokens - Royal Cinema Blue & Sapphire Dark Palette (matching Cineza website)
  static const Color kBackground = Color(0xFF090A0F); // AppTheme.darkBackground
  static const Color kSurfaceContainerLowest = Color(0xFF0C0F17);
  static const Color kSurfaceContainerLow = Color(0xFF141722); // AppTheme.darkSurface
  static const Color kSurfaceContainer = Color(0xFF1E2336); // AppTheme.darkSurfaceLight
  static const Color kSurfaceContainerHigh = Color(0xFF262B40); // AppTheme.darkSurfaceBorder
  static const Color kSurfaceVariant = Color(0xFF333A56);
  static const Color kPrimary = Color(0xFF60A5FA); // Sky Blue Accent
  static const Color kPrimaryContainer = Color(0xFF0062FF); // Vivid Royal Cinema Blue
  static const Color kOnPrimary = Color(0xFF0A265C); // Deep Royal Navy
  static const Color kSecondaryContainer = Color(0xFFFFB800); // Cineza Gold Star
  static const Color kSecondary = Color(0xFF38BDF8); // Electric Cyan
  static const Color kOutline = Color(0xFF94A3B8); // Slate outline
  static const Color kOnSurface = Color(0xFFF8FAFC); // Crisp white

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  // --- AUTH ACTIONS ---

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isGoogleLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Google sign-in failed. Please try again.';
      });
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isAppleLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _isAppleLoading = false;
        _errorMessage =
            'Apple Sign-In is configured for iOS. Please use Google or Mobile OTP on Web.';
      });
    }
  }

  // --- MSG91 PHONE OTP METHODS ---

  String _cleanPhoneDigits(String raw) {
    return raw.replaceAll(RegExp(r'[^0-9]'), '');
  }

  Future<void> _handlePhoneContinue() async {
    final digits = _cleanPhoneDigits(_phoneController.text);
    if (digits.length != 10) {
      setState(() => _errorMessage = 'Please enter a valid 10-digit mobile number.');
      return;
    }

    await _sendOtp('91$digits');
  }

  Future<void> _sendOtp(String formattedNumber) async {
    setState(() {
      _isOtpLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    if (!kIsWeb) {
      setState(() {
        _isOtpLoading = false;
        _errorMessage = 'MSG91 OTP is only supported on Web platform.';
      });
      return;
    }

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (mounted && _isOtpLoading) {
        setState(() {
          _isOtpLoading = false;
          _errorMessage =
              'OTP request timed out. Please check your network or MSG91 widget configuration.';
        });
      }
    });

    try {
      initMsg91();
      callSendOtp(
        formattedNumber,
        (data) {
          _timeoutTimer?.cancel();
          final reqId = _extractReqId(data);
          if (mounted) {
            setState(() {
              _reqId = reqId;
              _otpSent = true;
              _isOtpLoading = false;
              _successMessage = 'OTP sent successfully! Enter the code below.';
            });
          }
        },
        (error) {
          _timeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _isOtpLoading = false;
              _errorMessage =
                  error != null ? error.toString() : 'Failed to send OTP.';
            });
          }
        },
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _isOtpLoading = false;
          _errorMessage = 'Could not send OTP: $e';
        });
      }
    }
  }

  Future<bool> _verifyOtpWithCode(String otp) async {
    final completer = Completer<bool>();

    if (!kIsWeb) {
      completer.complete(false);
      return false;
    }

    try {
      callVerifyOtp(
        otp,
        (data) {
          final accessToken = _extractAccessToken(data);
          if (accessToken != null && accessToken.isNotEmpty) {
            _pendingAccessToken = accessToken;
            if (!completer.isCompleted) completer.complete(true);
          } else {
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        (error) {
          if (!completer.isCompleted) completer.complete(false);
        },
        _reqId,
      );
    } catch (_) {
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => false,
    );
  }

  Future<void> _finishLoginWithMsg91(String accessToken) async {
    try {
      await _authService.signInWithMsg91AccessToken(accessToken);
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/');
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOtpLoading = false;
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _resendOtp() async {
    final digits = _cleanPhoneDigits(_phoneController.text);
    if (digits.length != 10) return;

    setState(() {
      _isOtpLoading = true;
      _errorMessage = null;
    });

    try {
      callRetryOtp(
        '11', // SMS Channel
        (data) {
          final newReqId = _extractReqId(data);
          if (mounted) {
            setState(() {
              if (newReqId != null && newReqId.isNotEmpty) {
                _reqId = newReqId;
              }
              _isOtpLoading = false;
              _successMessage = 'OTP resent successfully.';
            });
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              _isOtpLoading = false;
              _errorMessage =
                  error != null ? error.toString() : 'Failed to resend OTP.';
            });
          }
        },
        _reqId,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isOtpLoading = false;
          _errorMessage = 'Could not resend OTP: $e';
        });
      }
    }
  }

  String? _extractReqId(dynamic dartData) {
    if (dartData == null) return null;
    if (dartData is Map) {
      for (final key in [
        'reqId',
        'req_id',
        'requestId',
        'request_id',
        'message',
        'data'
      ]) {
        final val = dartData[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val.toString().trim();
        }
      }
    } else if (dartData is String) {
      try {
        final decoded = jsonDecode(dartData);
        if (decoded is Map) return _extractReqId(decoded);
      } catch (_) {}
      return dartData.trim();
    }
    return dartData.toString();
  }

  String? _extractAccessToken(dynamic dartData) {
    if (dartData == null) return null;
    if (dartData is Map) {
      for (final key in [
        'accessToken',
        'access_token',
        'token',
        'jwtToken',
        'jwt_token',
        'message',
        'data'
      ]) {
        final val = dartData[key];
        if (val is String && val.trim().isNotEmpty) return val.trim();
      }
    } else if (dartData is String) {
      try {
        final decoded = jsonDecode(dartData);
        if (decoded is Map) return _extractAccessToken(decoded);
      } catch (_) {}
      if (dartData.trim().length > 20) return dartData.trim();
    }
    return null;
  }

  // --- UI BUILD METHOD ---

  @override
  Widget build(BuildContext context) {
    final hasValidPhone = _cleanPhoneDigits(_phoneController.text).length == 10;

    return Scaffold(
      backgroundColor: kBackground,
      body: Stack(
        children: [
          // Cinematic Ambient Background Glows
          Positioned(
            top: -120,
            left: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kPrimaryContainer.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: MediaQuery.of(context).size.width * 0.2,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kSecondary.withValues(alpha: 0.10),
              ),
            ),
          ),

          // Main Center Container
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 36),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Container(
                  decoration: BoxDecoration(
                    color: kSurfaceContainerLow.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: kSurfaceContainerHigh.withValues(alpha: 0.8),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.55),
                        blurRadius: 40,
                        offset: const Offset(0, 20),
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: kPrimaryContainer.withValues(alpha: 0.05),
                        blurRadius: 50,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        // Subtle Top Neon Accent Line
                        Positioned(
                          top: 0,
                          left: 48,
                          right: 48,
                          height: 2,
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  kPrimaryContainer,
                                  kSecondary,
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 36,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // 1. Header & Cineza Logo Badge
                              _buildHeaderSection(),
                              const SizedBox(height: 28),

                              // If OTP was sent, show the Animated OTP Verification View
                              if (_otpSent) ...[
                                _buildAnimatedOtpSection(),
                              ] else ...[
                                // Feedback / Error Banner
                                if (_errorMessage != null || _successMessage != null)
                                  _buildStatusBanner(),

                                // 2. Direct Mobile Number Input & Continue Button
                                _buildPhoneOtpForm(hasValidPhone),

                                const SizedBox(height: 24),

                                // 3. Modern Splitter / Divider
                                _buildDivider(),
                                const SizedBox(height: 20),

                                // 4. Social Auth Matrix (Google & Apple)
                                _buildSocialMatrix(),
                                const SizedBox(height: 28),

                                // 5. Cinema Benefits Micro Bar
                                _buildCinemaBenefitsBar(),
                                const SizedBox(height: 24),

                                // 6. Terms & Security Footer
                                _buildTermsFooter(),
                              ],
                            ],
                          ),
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

  // --- HEADER SECTION ---

  Widget _buildHeaderSection() {
    return Column(
      children: [
        // Glowing Logo Badge with Original Logo Asset
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kSurfaceVariant.withValues(alpha: 0.6),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimaryContainer.withValues(alpha: 0.25),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/images/cineza_logo_transparent.png',
                width: 34,
                height: 34,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 10),
              Text(
                'CINEZA',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.2,
                  color: kPrimaryContainer,
                ),
              ),
            ],
          ),
        ),

        // Headline
        Text(
          'Unlock Cinematic Perks',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: kOnSurface,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),

        // Subtitle
        Text(
          'Access exclusive premieres, instant seat reservations, curated snack combos & star tier rewards.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 13.5,
            color: kOutline,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // --- ANIMATED OTP VERIFICATION SECTION ---

  Widget _buildAnimatedOtpSection() {
    final phoneDigits = _cleanPhoneDigits(_phoneController.text);
    final formattedPhone = phoneDigits.length == 10
        ? '+91 ${phoneDigits.substring(0, 5)} ${phoneDigits.substring(5)}'
        : '+91 $phoneDigits';

    return OtpVerificationView(
      length: 4,
      title: "Let's verify your number",
      subtitle: "We've sent a 4-digit code to $formattedPhone.",
      onVerify: (code) async {
        return await _verifyOtpWithCode(code);
      },
      onSuccess: () {
        if (_pendingAccessToken != null && _pendingAccessToken!.isNotEmpty) {
          _finishLoginWithMsg91(_pendingAccessToken!);
        } else {
          Navigator.pushReplacementNamed(context, '/');
        }
      },
      onResend: () {
        _resendOtp();
      },
      onCancel: () {
        setState(() {
          _otpSent = false;
          _reqId = null;
          _errorMessage = null;
          _successMessage = null;
        });
      },
    );
  }

  // --- MOBILE PHONE INPUT FORM ---

  Widget _buildPhoneOtpForm(bool hasValidPhone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          'MOBILE NUMBER',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: kOutline,
          ),
        ),
        const SizedBox(height: 8),

        // Country code + Phone Input
        Row(
          children: [
            // Country Selector Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: kSurfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: kSurfaceContainerHigh.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Text('🇮🇳', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Text(
                    '+91',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: kOnSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: kOutline,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Phone Number Input
            Expanded(
              child: Container(
                height: 46,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: kSurfaceContainerLowest,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasValidPhone
                        ? kPrimaryContainer.withValues(alpha: 0.6)
                        : kSurfaceContainerHigh.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: kOnSurface,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter 10-digit number',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: kSurfaceVariant,
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    if (hasValidPhone)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: kPrimary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // Primary Submit Button
        _buildGradientButton(
          label: _isOtpLoading ? 'Sending OTP...' : 'Continue with OTP',
          icon: Icons.arrow_forward_rounded,
          isLoading: _isOtpLoading,
          onPressed: _isOtpLoading ? null : _handlePhoneContinue,
        ),
      ],
    );
  }

  // --- GRADIENT BUTTON ---

  Widget _buildGradientButton({
    required String label,
    required IconData icon,
    required bool isLoading,
    required VoidCallback? onPressed,
  }) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [kPrimaryContainer, kOnPrimary],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: kPrimaryContainer.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(10),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kOnSurface,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 18, color: kOnSurface),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  // --- DIVIDER ---

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: kSurfaceVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR CONTINUE WITH',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: kOutline,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: kSurfaceVariant)),
      ],
    );
  }

  // --- SOCIAL MATRIX (Google & Apple) ---

  Widget _buildSocialMatrix() {
    return Row(
      children: [
        // Google Button
        Expanded(
          child: SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: _isGoogleLoading ? null : _signInWithGoogle,
              style: OutlinedButton.styleFrom(
                backgroundColor: kSurfaceContainer,
                side: BorderSide(
                  color: kSurfaceContainerHigh.withValues(alpha: 0.6),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isGoogleLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'G',
                            style: TextStyle(
                              color: Color(0xFFEA4335),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Google',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kOnSurface,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Apple Button
        Expanded(
          child: SizedBox(
            height: 42,
            child: OutlinedButton(
              onPressed: _isAppleLoading ? null : _signInWithApple,
              style: OutlinedButton.styleFrom(
                backgroundColor: kSurfaceContainer,
                side: BorderSide(
                  color: kSurfaceContainerHigh.withValues(alpha: 0.6),
                  width: 1,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isAppleLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 1.8),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.apple_rounded,
                          size: 20,
                          color: kOnSurface,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Apple',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kOnSurface,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  // --- CINEMA BENEFITS MICRO BAR ---

  Widget _buildCinemaBenefitsBar() {
    return Container(
      padding: const EdgeInsets.only(top: 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: kSurfaceVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _benefitItem(
            customIcon: Image.asset(
              'assets/images/cineza_logo_transparent.png',
              width: 20,
              height: 20,
              fit: BoxFit.contain,
            ),
            label: 'Instant E-Ticket',
          ),
          Container(width: 1, height: 24, color: kSurfaceVariant),
          _benefitItem(
            icon: Icons.fastfood_rounded,
            iconColor: kPrimary,
            label: '20% Snack Off',
          ),
          Container(width: 1, height: 24, color: kSurfaceVariant),
          _benefitItem(
            icon: Icons.stars_rounded,
            iconColor: kSecondaryContainer,
            label: 'Star Club Points',
          ),
        ],
      ),
    );
  }

  Widget _benefitItem({
    IconData? icon,
    Color? iconColor,
    Widget? customIcon,
    required String label,
  }) {
    return Column(
      children: [
        customIcon ?? Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kOnSurface,
          ),
        ),
      ],
    );
  }

  // --- TERMS & SECURITY FOOTER ---

  Widget _buildTermsFooter() {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _openTermsPolicy(0),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              "By signing in, you agree to Cineza's ",
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: kOutline,
                height: 1.5,
              ),
            ),
          ),
        ),
        _buildLegalLink(
          label: 'Terms of Service',
          tabIndex: 0,
        ),
        Text(
          ' & ',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: kOutline,
            height: 1.5,
          ),
        ),
        _buildLegalLink(
          label: 'Privacy Policy',
          tabIndex: 1,
        ),
        Text(
          '.',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: kOutline,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _openTermsPolicy(int tabIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TermsPolicyScreen(initialTab: tabIndex),
        settings: RouteSettings(
          name: '/terms-policy',
          arguments: tabIndex,
        ),
      ),
    );
  }

  Widget _buildLegalLink({required String label, required int tabIndex}) {
    bool isHovered = false;
    return StatefulBuilder(
      builder: (context, setLinkState) {
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setLinkState(() => isHovered = true),
          onExit: (_) => setLinkState(() => isHovered = false),
          child: GestureDetector(
            onTap: () => _openTermsPolicy(tabIndex),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isHovered ? kSecondary : kPrimary.withValues(alpha: 0.7),
                    width: 1.2,
                  ),
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isHovered ? kSecondary : kPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // --- STATUS / ERROR BANNER ---

  Widget _buildStatusBanner() {
    final isError = _errorMessage != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isError
            ? const Color(0xFF231014)
            : const Color(0xFF0D2137),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError
              ? const Color(0xFFEF4444)
              : const Color(0xFF0062FF),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            size: 17,
            color: isError ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isError ? _errorMessage! : _successMessage!,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: isError ? const Color(0xFFFCA5A5) : const Color(0xFFBAE6FD),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
