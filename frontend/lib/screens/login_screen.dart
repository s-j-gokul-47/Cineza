import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart' show User;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/login_js_helper.dart';
import '../widgets/otp_verification_view.dart';
import '../theme/app_theme.dart';
import 'terms_policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final ApiService _apiService = ApiService();

  // Mobile Controller & OTP State
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  bool _otpSent = false;
  bool _needsUsername = false;
  bool _isSavingUsername = false;
  String? _authenticatedPhone;
  String? _reqId;
  String? _pendingAccessToken;
  Timer? _timeoutTimer;

  // Cinema Clapperboard Animation & State
  late AnimationController _clapController;
  late Animation<double> _clapAngleAnimation;
  late Animation<double> _impactFlashAnimation;
  late Animation<double> _actionStampAnimation;
  bool _isClapTriggered = false;

  // Loading & Feedback
  bool _isGoogleLoading = false;
  bool _isAppleLoading = false;
  bool _isOtpLoading = false;
  String? _errorMessage;
  String? _successMessage;

  // Dynamic Theme Tokens (Google Stitch Cinema System)
  bool get isDark => ThemeController.isDark(context);

  Color get kBackground => AppTheme.getBackground(isDark);
  Color get kSurfaceContainerLowest => isDark ? AppTheme.darkSurfaceLowest : AppTheme.lightSurfaceContainer;
  Color get kSurfaceContainerLow => isDark ? AppTheme.darkSurface : AppTheme.lightSurface;
  Color get kSurfaceContainer => isDark ? AppTheme.darkSurfaceContainer : AppTheme.lightSurfaceContainer;
  Color get kSurfaceContainerHigh => isDark ? AppTheme.darkSurfaceBorder : AppTheme.lightSurfaceBorder;
  Color get kSurfaceVariant => isDark ? AppTheme.darkSurfaceHighest : AppTheme.lightSurfaceHighest;
  Color get kPrimary => isDark ? AppTheme.primary : AppTheme.lightPrimary;
  Color get kPrimaryContainer => isDark ? AppTheme.primary : AppTheme.lightPrimary;
  Color get kOnPrimary => isDark ? AppTheme.darkOnPrimary : AppTheme.lightOnPrimary;
  Color get kSecondaryContainer => AppTheme.getGoldAccent(isDark);
  Color get kSecondary => isDark ? AppTheme.accent : AppTheme.lightPrimary;
  Color get kOutline => AppTheme.getTextMuted(isDark);
  Color get kOnSurface => AppTheme.getTextPrimary(isDark);

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {});
    });

    // Clapperboard Clap Controller (Initial open state: -0.34 rad ~= -19.5 degrees)
    _clapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _clapAngleAnimation = Tween<double>(
      begin: -0.34,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _clapController,
      curve: const Interval(0.0, 0.70, curve: Curves.easeInQuad),
    ));

    _impactFlashAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _clapController,
      curve: const Interval(0.65, 0.90, curve: Curves.easeInOut),
    ));

    _actionStampAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _clapController,
      curve: const Interval(0.70, 1.0, curve: Curves.elasticOut),
    ));
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _clapController.dispose();
    _phoneController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  // --- CINEMA CLAP & NAVIGATION TRIGGER ---

  Future<void> _triggerClapAndNavigate() async {
    if (_isClapTriggered) return;
    setState(() {
      _isClapTriggered = true;
      _errorMessage = null;
    });

    playClapperSound();
    await _clapController.forward();
    await Future.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
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
      await _triggerClapAndNavigate();
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
              _errorMessage = _formatOtpError(error);
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

  String _formatOtpError(dynamic error) {
    if (error == null) return 'Failed to send OTP. Please try again.';
    final str = error.toString();
    if (str.contains('AuthenticationFailure') || str.contains('401')) {
      return 'MSG91 Authentication Failed (401): Please enter your real MSG91 Token Auth in web/index.html to send live SMS.';
    }
    if (str.contains('still initializing')) {
      return 'MSG91 OTP widget is initializing. If this persists, please verify your MSG91 Widget ID and Token Auth in web/index.html.';
    }
    if (str.contains('404')) {
      return 'Widget Not Found (404): Please check your MSG91 Widget ID in web/index.html.';
    }
    return str;
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
    final digits = _cleanPhoneDigits(_phoneController.text);
    _authenticatedPhone = digits.isNotEmpty ? '+91$digits' : null;

    setState(() {
      _isOtpLoading = true;
      _errorMessage = null;
    });

    // 1. Attempt Firebase authentication via custom token with 3-second timeout
    try {
      await _authService.signInWithMsg91AccessToken(accessToken).timeout(
        const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('[Login] Firebase custom token exchange skipped or failed: $e');
      // Ensure Firebase has an active user session if custom token failed
      try {
        if (_authService.currentUser == null) {
          await _authService.signInAnonymously();
        }
      } catch (err) {
        debugPrint('[Login] Anonymous sign-in skipped: $err');
      }
    }

    // 2. Check if this phone number or Firebase user already has a configured username in MySQL
    String? existingUsername;
    final user = _authService.currentUser;
    if (user != null &&
        user.displayName != null &&
        user.displayName!.trim().isNotEmpty &&
        user.displayName != 'Cineza User') {
      existingUsername = user.displayName!.trim();
    }

    if (existingUsername == null || existingUsername.isEmpty) {
      try {
        final phone = _authenticatedPhone;
        if (phone != null) {
          final dbUser = await _apiService.getUserByPhone(phone);
          if (dbUser != null &&
              dbUser['username'] != null &&
              dbUser['username'].toString().trim().isNotEmpty) {
            existingUsername = dbUser['username'].toString().trim();
            if (user != null) {
              await user.updateDisplayName(existingUsername);
              await user.reload();
            }
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    // 3. If username is already established, route directly to Home; otherwise show username setup!
    if (existingUsername != null &&
        existingUsername.isNotEmpty &&
        existingUsername != 'Cineza User') {
      await _triggerClapAndNavigate();
    } else {
      // Transition immediately to the username setup form!
      setState(() {
        _needsUsername = true;
        _otpSent = false;
        _isOtpLoading = false;
        _errorMessage = null;
        _successMessage = null;
      });
    }
  }

  Future<void> _saveUsernameAndProceed({String? fallbackUsername}) async {
    final cleanUsername = (fallbackUsername ?? _usernameController.text).trim();
    if (cleanUsername.isEmpty) {
      setState(() => _errorMessage = 'Please enter a username.');
      return;
    }
    if (cleanUsername.length < 2) {
      setState(() => _errorMessage = 'Username must be at least 2 characters long.');
      return;
    }

    setState(() {
      _isSavingUsername = true;
      _errorMessage = null;
    });

    try {
      final digits = _cleanPhoneDigits(_phoneController.text);
      final phone = _authenticatedPhone ?? (digits.isNotEmpty ? '+91$digits' : null);

      // Ensure Firebase session exists
      User? user = _authService.currentUser;
      if (user == null) {
        try {
          final cred = await _authService.signInAnonymously();
          user = cred.user;
        } catch (_) {}
      }

      if (user != null) {
        try {
          await user.updateDisplayName(cleanUsername);
          await user.reload();
        } catch (_) {}
      }

      final firebaseUid = user?.uid ?? 'phone_${digits.isNotEmpty ? digits : DateTime.now().millisecondsSinceEpoch}';

      // Persist user to MySQL database via Spring Boot REST endpoint
      await _apiService.syncUser(
        firebaseUid: firebaseUid,
        username: cleanUsername,
        phoneNumber: phone,
        authProvider: 'PHONE',
      );

      if (!mounted) return;
      await _triggerClapAndNavigate();
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingUsername = false;
          _errorMessage = 'Could not save username: $e';
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
              _errorMessage = _formatOtpError(error);
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

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, currentMode, _) {
        final isDarkMode = currentMode == ThemeMode.dark;

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
                    color: kPrimary.withValues(alpha: isDarkMode ? 0.12 : 0.05),
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
                    color: kSecondaryContainer.withValues(alpha: isDarkMode ? 0.08 : 0.04),
                  ),
                ),
              ),

              // Main Center Cinema Clapperboard Container
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
                  child: AnimatedBuilder(
                    animation: _clapController,
                    builder: (context, _) {
                      final screenWidth = MediaQuery.of(context).size.width;
                      final clapperWidth = (screenWidth < 590 ? screenWidth - 32 : 558.0).clamp(290.0, 558.0);
                      final stickHeight = clapperWidth < 380 ? 32.0 : 38.0;
                      // Maximum vertical rise of the angled stick is clapperWidth * sin(19.5 deg) ~= clapperWidth * 0.33
                      final topClearance = clapperWidth * 0.34;
                      final stripeW = clapperWidth < 400 ? 20.0 : 25.0;

                      return SizedBox(
                        width: clapperWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // 1. TOP CLAPPER STICKS AREA (Upper moving stick + lower stationary stick)
                            SizedBox(
                              width: clapperWidth,
                              height: topClearance + stickHeight,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  // Lower Stationary Stick (directly above the slate body)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: stickHeight,
                                    child: CustomPaint(
                                      painter: ClapperStickPainter(
                                        isTop: false,
                                        stripeWidth: stripeW,
                                      ),
                                    ),
                                  ),

                                  // Upper Moving Stick (pivoting on bottom-left hinge)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    height: stickHeight,
                                    child: Transform(
                                      alignment: Alignment.bottomLeft,
                                      transform: Matrix4.rotationZ(_clapAngleAnimation.value),
                                      child: CustomPaint(
                                        painter: ClapperStickPainter(
                                          isTop: true,
                                          stripeWidth: stripeW,
                                        ),
                                      ),
                                    ),
                                  ),

                                  // Impact Flash Beam when the two sticks collide shut
                                  Positioned(
                                    left: 45,
                                    right: 0,
                                    bottom: 0,
                                    height: 5,
                                    child: Builder(
                                      builder: (context) {
                                        final v = _impactFlashAnimation.value;
                                        if (v <= 0.05) return const SizedBox.shrink();
                                        return Container(
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.transparent,
                                                AppTheme.goldAccent.withValues(alpha: v * 0.9),
                                                Colors.white.withValues(alpha: v),
                                                kPrimary.withValues(alpha: v * 0.8),
                                                Colors.transparent,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withValues(alpha: v * 0.95),
                                                blurRadius: 18 * v,
                                                spreadRadius: 4 * v,
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  // Metallic Hinge Bracket on left (securing both sticks with screws)
                                  Positioned(
                                    left: 0,
                                    bottom: 0,
                                    width: clapperWidth < 400 ? 46 : 56,
                                    height: stickHeight * 1.65,
                                    child: CustomPaint(
                                      painter: HingeBracketPainter(),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // 2. MAIN SLATE CHALKBOARD BODY (Holding the login contents)
                            Container(
                              width: clapperWidth,
                              decoration: BoxDecoration(
                                color: isDarkMode ? const Color(0xFF13151D) : const Color(0xFF1C1F28),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(24),
                                  bottomRight: Radius.circular(24),
                                ),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.70),
                                    blurRadius: 36,
                                    offset: const Offset(0, 18),
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: kPrimary.withValues(alpha: 0.12),
                                    blurRadius: 45,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(24),
                                  bottomRight: Radius.circular(24),
                                ),
                                child: Stack(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: clapperWidth < 380 ? 18 : 28,
                                        vertical: 28,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          // 1. Header & Cineza Logo Badge
                                          if (_needsUsername)
                                            _buildUsernameSetupHeader()
                                          else
                                            _buildHeaderSection(),
                                          const SizedBox(height: 24),

                                          // Feedback / Error Banner
                                          if (_errorMessage != null || _successMessage != null)
                                            _buildStatusBanner(),

                                          // State switcher: Username Setup vs OTP view vs Phone/Social form
                                          if (_needsUsername) ...[
                                            _buildUsernameSetupForm(),
                                          ] else if (_otpSent) ...[
                                            _buildAnimatedOtpSection(),
                                          ] else ...[
                                            // 2. Direct Mobile Number Input & Continue Button
                                            _buildPhoneOtpForm(hasValidPhone),

                                            const SizedBox(height: 20),

                                            // 3. Modern Splitter / Divider
                                            _buildDivider(),
                                            const SizedBox(height: 18),

                                            // 4. Social Auth Matrix (Google & Apple)
                                            _buildSocialMatrix(),
                                            const SizedBox(height: 24),

                                            // 5. Terms & Security Footer
                                            _buildTermsFooter(),
                                          ],
                                        ],
                                      ),
                                    ),

                                    // 3. "ACTION!" Director Stamp Overlay (Appears on successful clap)
                                    if (_isClapTriggered)
                                      Positioned.fill(
                                        child: Builder(
                                          builder: (context) {
                                            final scale = _actionStampAnimation.value;
                                            if (scale <= 0.05) return const SizedBox.shrink();
                                            return Center(
                                              child: Transform.rotate(
                                                angle: -0.08,
                                                child: Transform.scale(
                                                  scale: scale,
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black.withValues(alpha: 0.90),
                                                      borderRadius: BorderRadius.circular(16),
                                                      border: Border.all(
                                                        color: kPrimary,
                                                        width: 3,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: kPrimary.withValues(alpha: 0.6),
                                                          blurRadius: 30,
                                                          spreadRadius: 4,
                                                        ),
                                                      ],
                                                    ),
                                                    child: Column(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.movie_filter_rounded, color: Colors.white, size: 28),
                                                            const SizedBox(width: 10),
                                                            Text(
                                                              'ACTION!',
                                                              style: GoogleFonts.plusJakartaSans(
                                                                fontSize: 28,
                                                                fontWeight: FontWeight.w900,
                                                                letterSpacing: 3.0,
                                                                color: Colors.white,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Text(
                                                          'SCENE 01: AUTHORIZED • ENTERING CINEZA',
                                                          style: GoogleFonts.plusJakartaSans(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: 1.5,
                                                            color: AppTheme.goldAccent,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Top Floating Bar (Return to Movies & CinezaThemeToggle)
              Positioned(
                top: 16,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Back to Movies',
                      onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: kSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kSurfaceContainerHigh),
                        ),
                        child: Icon(Icons.arrow_back_rounded, color: kOnSurface, size: 20),
                      ),
                    ),
                    CinezaThemeToggle(compact: MediaQuery.of(context).size.width < 500),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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
      ],
    );
  }

  // --- USERNAME SETUP SECTION (POST-OTP) ---

  Widget _buildUsernameSetupHeader() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: kPrimary.withValues(alpha: 0.5),
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
              Icon(
                Icons.person_pin_rounded,
                color: kSecondary,
                size: 22,
              ),
              const SizedBox(width: 8),
              Text(
                'ONE LAST STEP',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: kSecondary,
                ),
              ),
            ],
          ),
        ),
        Text(
          'Enter Your Username',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: kOnSurface,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Mobile verified! Choose a username to personalize your Cineza bookings and movie club perks.',
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

  Widget _buildUsernameSetupForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CHOOSE USERNAME',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: kOutline,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: kSurfaceContainerLowest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: kPrimaryContainer.withValues(alpha: 0.6),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.account_circle_outlined,
                color: kPrimary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _usernameController,
                  autofocus: true,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: kOnSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'e.g. Cinephile99 or Alex_Film',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 13.5,
                      color: kSurfaceVariant,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onSubmitted: (_) {
                    if (!_isSavingUsername) _saveUsernameAndProceed();
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _buildGradientButton(
          label: _isSavingUsername ? 'Saving Username...' : 'Save & Enter Cineza',
          icon: Icons.check_circle_rounded,
          isLoading: _isSavingUsername,
          onPressed: _isSavingUsername ? null : _saveUsernameAndProceed,
        ),
        const SizedBox(height: 14),
        Center(
          child: TextButton(
            onPressed: () {
              final digits = _cleanPhoneDigits(_phoneController.text);
              final defaultName = digits.length >= 4
                  ? 'User_${digits.substring(digits.length - 4)}'
                  : 'Cineza Member';
              _saveUsernameAndProceed(fallbackUsername: defaultName);
            },
            child: Text(
              'Skip for now',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: kOutline,
                decoration: TextDecoration.underline,
              ),
            ),
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
          final digits = _cleanPhoneDigits(_phoneController.text);
          _authenticatedPhone = digits.isNotEmpty ? '+91$digits' : null;
          setState(() {
            _needsUsername = true;
            _otpSent = false;
            _isOtpLoading = false;
            _errorMessage = null;
          });
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
                  Icon(
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
                      Icon(
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
        gradient: LinearGradient(
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
                        Icon(
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

/// Authentic Cinema Clapperboard Diagonal Striped Stick Painter
class ClapperStickPainter extends CustomPainter {
  final bool isTop;
  final double stripeWidth;

  const ClapperStickPainter({
    required this.isTop,
    this.stripeWidth = 26.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndCorners(
      rect,
      topLeft: isTop ? const Radius.circular(6) : Radius.zero,
      topRight: const Radius.circular(6),
      bottomLeft: isTop ? const Radius.circular(4) : Radius.zero,
      bottomRight: isTop ? const Radius.circular(4) : Radius.zero,
    );

    canvas.save();
    canvas.clipRRect(rrect);

    // Deep slate black base
    final basePaint = Paint()..color = const Color(0xFF141720);
    canvas.drawRect(rect, basePaint);

    // Diagonal White Stripes at ~45 degrees
    final stripePaint = Paint()
      ..color = const Color(0xFFF8FAFC)
      ..style = PaintingStyle.fill;

    final slant = size.height * 0.95;
    final step = stripeWidth * 2.0;

    for (double x = -size.height * 1.5; x < size.width + size.height * 1.5; x += step) {
      final path = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + slant, 0)
        ..lineTo(x + slant + stripeWidth, 0)
        ..lineTo(x + stripeWidth, size.height)
        ..close();
      canvas.drawPath(path, stripePaint);
    }

    // Top surface shine / bevel gradient
    final bevelPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.transparent,
          Colors.black.withValues(alpha: 0.45),
        ],
        stops: const [0.0, 0.22, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bevelPaint);

    // Outer subtle border
    final borderPaint = Paint()
      ..color = const Color(0xFF0F1117)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRect(rect, borderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ClapperStickPainter oldDelegate) {
    return oldDelegate.isTop != isTop || oldDelegate.stripeWidth != stripeWidth;
  }
}

/// Realistic Metallic Gunmetal Hinge Bracket with Silver Screws
class HingeBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bracketRRect = RRect.fromRectAndCorners(
      rect,
      topLeft: const Radius.circular(6),
      bottomLeft: const Radius.circular(6),
      topRight: const Radius.circular(4),
      bottomRight: const Radius.circular(4),
    );

    // Dark brushed gunmetal gradient
    final metalPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF4C5466),
          Color(0xFF262A34),
          Color(0xFF1B1E26),
          Color(0xFF383E4C),
        ],
      ).createShader(rect);
    canvas.drawRRect(bracketRRect, metalPaint);

    // Bracket border highlight
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bracketRRect, borderPaint);

    // Metallic Screws / Rivets
    void drawScrew(Offset center, double r) {
      // Outer shadow
      final shadowPaint = Paint()..color = Colors.black45;
      canvas.drawCircle(Offset(center.dx, center.dy + 1), r, shadowPaint);

      // Silver metal face
      final screwPaint = Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFFE2E8F0),
            Color(0xFF94A3B8),
            Color(0xFF475569),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r));
      canvas.drawCircle(center, r, screwPaint);

      // Screw slot (cross line)
      final slotPaint = Paint()
        ..color = const Color(0xFF1E293B)
        ..strokeWidth = 1.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx - r * 0.65, center.dy),
        Offset(center.dx + r * 0.65, center.dy),
        slotPaint,
      );
    }

    final screwRadius = size.width < 50 ? 3.8 : 4.5;
    drawScrew(Offset(size.width * 0.35, size.height * 0.22), screwRadius);
    drawScrew(Offset(size.width * 0.35, size.height * 0.78), screwRadius);
    drawScrew(Offset(size.width * 0.72, size.height * 0.78), screwRadius);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

