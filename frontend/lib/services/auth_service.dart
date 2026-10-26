import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';

class AuthService {
  static const String _workerOtpUrl =
      'https://cineza-auth-api.gokulakannansj.workers.dev/auth/otp';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiService _apiService = ApiService();

  Future<UserCredential> signInWithGoogle() async {
    final UserCredential credential;
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      credential = await _auth.signInWithPopup(provider);
    } else {
      final googleSignIn = GoogleSignIn.instance;
      await googleSignIn.initialize();

      final googleUser = await googleSignIn.authenticate();
      final googleAuth = googleUser.authentication;

      final cred = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      credential = await _auth.signInWithCredential(cred);
    }

    // Ensure the Google user's name is saved as their username and synchronized to the database
    final user = credential.user;
    if (user != null) {
      String resolvedName = '';
      if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
        resolvedName = user.displayName!.trim();
      }
      if (resolvedName.isEmpty && credential.additionalUserInfo?.profile != null) {
        final profile = credential.additionalUserInfo!.profile!;
        if (profile['name'] != null && profile['name'].toString().trim().isNotEmpty) {
          resolvedName = profile['name'].toString().trim();
        }
      }
      if (resolvedName.isEmpty && user.providerData.isNotEmpty) {
        for (final info in user.providerData) {
          if (info.displayName != null && info.displayName!.trim().isNotEmpty) {
            resolvedName = info.displayName!.trim();
            break;
          }
        }
      }
      if (resolvedName.isEmpty && user.email != null && user.email!.isNotEmpty) {
        resolvedName = user.email!.split('@').first;
      }
      if (resolvedName.isEmpty) {
        resolvedName = 'Cineza User';
      }

      try {
        await user.updateDisplayName(resolvedName);
        await user.reload();
      } catch (_) {}

      // Store/Sync in backend MySQL users table
      try {
        await _apiService.syncUser(
          firebaseUid: user.uid,
          username: resolvedName,
          email: user.email,
          phoneNumber: user.phoneNumber,
          authProvider: 'GOOGLE',
          profilePicUrl: user.photoURL,
        );
      } catch (_) {}
    }

    return credential;
  }

  /// Automatically resolves and synchronizes user profile between Firebase and MySQL
  Future<String> resolveAndSyncUser(User user) async {
    String resolvedName = '';
    if (user.displayName != null && user.displayName!.trim().isNotEmpty) {
      resolvedName = user.displayName!.trim();
    }

    if (resolvedName.isEmpty && user.providerData.isNotEmpty) {
      for (final info in user.providerData) {
        if (info.displayName != null && info.displayName!.trim().isNotEmpty) {
          resolvedName = info.displayName!.trim();
          break;
        }
      }
    }

    // Check backend MySQL database
    if (resolvedName.isEmpty) {
      try {
        final dbUser = await _apiService.getUserProfile(user.uid);
        if (dbUser != null && dbUser['username'] != null && dbUser['username'].toString().trim().isNotEmpty) {
          resolvedName = dbUser['username'].toString().trim();
        }
      } catch (_) {}
    }

    if (resolvedName.isEmpty && user.email != null && user.email!.isNotEmpty) {
      resolvedName = user.email!.split('@').first;
    }

    if (resolvedName.isNotEmpty && user.displayName != resolvedName) {
      try {
        await user.updateDisplayName(resolvedName);
        await user.reload();
      } catch (_) {}
    }

    // Sync to MySQL
    if (resolvedName.isNotEmpty) {
      try {
        await _apiService.syncUser(
          firebaseUid: user.uid,
          username: resolvedName,
          email: user.email,
          phoneNumber: user.phoneNumber,
          authProvider: user.phoneNumber != null ? 'PHONE' : 'GOOGLE',
          profilePicUrl: user.photoURL,
        );
      } catch (_) {}
    }

    return resolvedName.isNotEmpty ? resolvedName : 'Cineza User';
  }

  /// Update the current user's username both in Firebase Auth and MySQL database
  Future<void> updateUsername(String newUsername) async {
    final user = _auth.currentUser;
    if (user != null) {
      final cleanName = newUsername.trim();
      await user.updateDisplayName(cleanName);
      await user.reload();

      await _apiService.syncUser(
        firebaseUid: user.uid,
        username: cleanName,
        email: user.email,
        phoneNumber: user.phoneNumber,
        authProvider: user.phoneNumber != null ? 'PHONE' : 'GOOGLE',
        profilePicUrl: user.photoURL,
      );
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<UserCredential> registerWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (displayName != null && displayName.trim().isNotEmpty) {
      await userCredential.user?.updateDisplayName(displayName.trim());
    }
    return userCredential;
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

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      await GoogleSignIn.instance.signOut();
    }
  }

  User? get currentUser => _auth.currentUser;
}
