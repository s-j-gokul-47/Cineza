import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/login_js_helper.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  String? _reqId;
  bool _otpSent = false;
  bool _isGoogleLoading = false;
  bool _isOtpLoading = false;
  String? _errorMessage;
  Timer? _timeoutTimer;

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

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
      if (mounted) {
        setState(() => _isGoogleLoading = false);
      }
    }
  }

  String _normalizeIdentifier(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) {
      return trimmed;
    }
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    // Auto-prefix 91 for standard 10-digit mobile numbers
    if (digits.length == 10) {
      return '91$digits';
    }
    return digits;
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
        if (decoded is Map) {
          return _extractReqId(decoded);
        }
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
        if (val is String && val.trim().isNotEmpty) {
          return val.trim();
        }
      }
    } else if (dartData is String) {
      try {
        final decoded = jsonDecode(dartData);
        if (decoded is Map) {
          return _extractAccessToken(decoded);
        }
      } catch (_) {}
      if (dartData.trim().length > 20) {
        return dartData.trim();
      }
    }
    return null;
  }

  Future<void> _sendOtp() async {
    final identifier = _normalizeIdentifier(_phoneController.text);

    if (identifier.isEmpty) {
      setState(() {
        _errorMessage =
            'Enter your phone number (e.g. 919876543210) or email address.';
      });
      return;
    }

    setState(() {
      _isOtpLoading = true;
      _errorMessage = null;
    });

    if (!kIsWeb) {
      setState(() {
        _isOtpLoading = false;
        _errorMessage = 'MSG91 OTP is only supported on Web platform.';
      });
      return;
    }

    // Safety timeout to prevent infinite UI freeze
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
        identifier,
        (data) {
          _timeoutTimer?.cancel();
          final reqId = _extractReqId(data);
          if (mounted) {
            setState(() {
              _reqId = reqId;
              _otpSent = true;
              _isOtpLoading = false;
            });
          }
        },
        (error) {
          _timeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _isOtpLoading = false;
              _errorMessage = error != null
                  ? error.toString()
                  : 'Failed to send OTP.';
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

  Future<void> _verifyOtp() async {
    final otp = _otpController.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please enter the OTP.');
      return;
    }

    setState(() {
      _isOtpLoading = true;
      _errorMessage = null;
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
          _errorMessage = 'Verification timed out. Please try again.';
        });
      }
    });

    try {
      callVerifyOtp(
        otp,
        (data) {
          _timeoutTimer?.cancel();
          final accessToken = _extractAccessToken(data);

          if (accessToken == null || accessToken.isEmpty) {
            if (mounted) {
              setState(() {
                _isOtpLoading = false;
                _errorMessage =
                    'OTP verified, but access token was missing in response.';
              });
            }
            return;
          }

          _finishLoginWithMsg91(accessToken);
        },
        (error) {
          _timeoutTimer?.cancel();
          if (mounted) {
            setState(() {
              _isOtpLoading = false;
              _errorMessage = error != null
                  ? error.toString()
                  : 'Invalid OTP. Please try again.';
            });
          }
        },
        _reqId,
      );
    } catch (e) {
      _timeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _isOtpLoading = false;
          _errorMessage = 'Verification failed: $e';
        });
      }
    }
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
    final identifier = _normalizeIdentifier(_phoneController.text);
    final isEmail = identifier.contains('@');
    final channel = isEmail ? '3' : '11';

    setState(() {
      _isOtpLoading = true;
      _errorMessage = null;
    });

    if (!kIsWeb) {
      setState(() {
        _isOtpLoading = false;
        _errorMessage = 'MSG91 OTP is only supported on Web platform.';
      });
      return;
    }

    try {
      callRetryOtp(
        channel,
        (data) {
          final newReqId = _extractReqId(data);
          if (mounted) {
            setState(() {
              if (newReqId != null && newReqId.isNotEmpty) {
                _reqId = newReqId;
              }
              _isOtpLoading = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('OTP resent successfully.')),
            );
          }
        },
        (error) {
          if (mounted) {
            setState(() {
              _isOtpLoading = false;
              _errorMessage = error != null
                  ? error.toString()
                  : 'Failed to resend OTP.';
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

  @override
  Widget build(BuildContext context) {
    final isActionBlocked = _isGoogleLoading || _isOtpLoading;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.movie_creation_outlined, size: 64),
                const SizedBox(height: 16),
                Text(
                  'Welcome to Cineza',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in to continue to your movie experience.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                OutlinedButton.icon(
                  onPressed: isActionBlocked ? null : _signInWithGoogle,
                  icon: const Icon(Icons.login),
                  label: Text(
                    _isGoogleLoading ? 'Signing in...' : 'Continue with Google',
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Phone number or Email',
                    hintText: '919876543210 or user@example.com',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.contact_phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_otpSent)
                  OutlinedButton(
                    onPressed: isActionBlocked ? null : _sendOtp,
                    child: Text(_isOtpLoading ? 'Sending OTP...' : 'Send OTP'),
                  ),
                if (_otpSent) ...[
                  TextField(
                    controller: _otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Enter OTP',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: isActionBlocked ? null : _verifyOtp,
                    child: Text(
                      _isOtpLoading ? 'Verifying...' : 'Verify OTP',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: isActionBlocked ? null : _resendOtp,
                    child: const Text('Resend OTP'),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
