import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthService {
  static const String _workerOtpUrl =
      'https://cineza-auth-api.gokulakannansj.workers.dev/auth/otp';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      return await _auth.signInWithPopup(provider);
    }

    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize();

    final googleUser = await googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  /// Exchanges MSG91 accessToken for a Firebase custom token via Cloudflare Worker
  /// and signs in to Firebase.
  Future<UserCredential> signInWithMsg91AccessToken(String accessToken) async {
    final response = await http.post(
      Uri.parse(_workerOtpUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'accessToken': accessToken}),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final customToken = data['customToken'] as String?;

      if (customToken == null || customToken.isEmpty) {
        throw Exception('Worker did not return a valid custom token.');
      }

      return await _auth.signInWithCustomToken(customToken);
    } else {
      String errorMessage =
          'Failed to verify OTP with Worker (status ${response.statusCode})';
      try {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        if (errorData['error'] != null) {
          errorMessage = errorData['error'].toString();
        } else if (errorData['message'] != null) {
          errorMessage = errorData['message'].toString();
        }
      } catch (_) {
        // Fallback to default message
      }
      throw Exception(errorMessage);
    }
  }

  Future<ConfirmationResult> sendPhoneOtpWeb({
    required String phoneNumber,
  }) async {
    return await _auth.signInWithPhoneNumber(phoneNumber);
  }

  Future<UserCredential> verifyPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );

    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }

  User? get currentUser => _auth.currentUser;
}
