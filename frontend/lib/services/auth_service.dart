import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'location_service.dart';
import 'login_js_helper.dart';

class AuthService {
  static const String _workerOtpUrl = AppConfig.authOtpUrl;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ApiService _apiService = ApiService();

  /// Reactive notifier holding the currently authenticated Cineza user across Firebase, Phone OTP, and MySQL
    static final ValueNotifier<CinezaUser?> currentUserNotifier =
      ValueNotifier<CinezaUser?>(null);

  /// Synchronous getter for active CinezaUser
  static CinezaUser? get currentUser => currentUserNotifier.value;

  /// Check whether an authenticated session is active
  static bool get isLoggedIn => currentUserNotifier.value != null;

  /// Underlying Firebase user instance (if authenticated via Firebase)
  User? get firebaseUser => _auth.currentUser;

  /// Backwards-compatible getter for Firebase User
  User? get currentUserInstance => _auth.currentUser;

  /// Initialize and hydrate auth state on app startup
  static void initialize() {
    // 1. Try loading cached session from Web localStorage
    try {
      final cachedJson = loadWebUserSession();
      if (cachedJson != null && cachedJson.trim().isNotEmpty) {
        final Map<String, dynamic> map = jsonDecode(cachedJson);
        if (map['uid'] != null && map['uid'].toString().isNotEmpty) {
          currentUserNotifier.value = CinezaUser.fromJson(map);
        }
      }
    } catch (_) {}

    // 2. If Firebase already has an active user, prioritize or sync it
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      currentUserNotifier.value = CinezaUser.fromFirebaseUser(fbUser);
      try {
        saveWebUserSession(jsonEncode(currentUserNotifier.value!.toJson()));
      } catch (_) {}
    }

    // 3. Listen to Firebase auth state changes
    FirebaseAuth.instance.authStateChanges().listen((fbUser) {
      if (fbUser != null) {
        currentUserNotifier.value = CinezaUser.fromFirebaseUser(fbUser);
        try {
          saveWebUserSession(jsonEncode(currentUserNotifier.value!.toJson()));
        } catch (_) {}
      } else {
        // If Firebase user signed out, check if current was a Firebase-driven provider (GOOGLE, EMAIL)
        if (currentUserNotifier.value != null &&
            currentUserNotifier.value!.authProvider != 'PHONE') {
          currentUserNotifier.value = null;
          try {
            saveWebUserSession('');
          } catch (_) {}
        }
      }
    });
  }

  /// Explicitly store or update session user (used by phone verification & username setup)
  static void setSessionUser(CinezaUser user) {
    currentUserNotifier.value = user;
    try {
      saveWebUserSession(jsonEncode(user.toJson()));
    } catch (_) {}
  }

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
        resolvedName = 'Cineza Member';
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

      final cinezaUser = CinezaUser.fromFirebaseUser(user, overrideDisplayName: resolvedName);
      setSessionUser(cinezaUser);
    }

    return credential;
  }

  /// Automatically resolves and synchronizes user profile between Firebase, MySQL, and session
  Future<String> resolveAndSyncUser(dynamic user) async {
    String uid = '';
    String? currentDisplayName;
    String? email;
    String? phoneNumber;
    String? photoUrl;
    User? fbUser;

    if (user is User) {
      fbUser = user;
      uid = user.uid;
      currentDisplayName = user.displayName;
      email = user.email;
      phoneNumber = user.phoneNumber;
      photoUrl = user.photoURL;
    } else if (user is CinezaUser) {
      uid = user.uid;
      currentDisplayName = user.displayName;
      email = user.email;
      phoneNumber = user.phoneNumber;
      photoUrl = user.photoURL;
      fbUser = _auth.currentUser;
    }

    String resolvedName = '';
    if (currentDisplayName != null &&
        currentDisplayName.trim().isNotEmpty &&
        currentDisplayName != 'Cineza User' &&
        currentDisplayName != 'Cineza Member') {
      resolvedName = currentDisplayName.trim();
    }

    // Check MySQL database
    if (resolvedName.isEmpty && uid.isNotEmpty) {
      try {
        final dbUser = await _apiService.getUserProfile(uid);
        if (dbUser != null &&
            dbUser['username'] != null &&
            dbUser['username'].toString().trim().isNotEmpty) {
          resolvedName = dbUser['username'].toString().trim();
        }
      } catch (_) {}
    }

    // Fallback to phone lookup in MySQL if phone number is present
    if (resolvedName.isEmpty && phoneNumber != null && phoneNumber.isNotEmpty) {
      try {
        final dbUser = await _apiService.getUserByPhone(phoneNumber);
        if (dbUser != null &&
            dbUser['username'] != null &&
            dbUser['username'].toString().trim().isNotEmpty) {
          resolvedName = dbUser['username'].toString().trim();
        }
      } catch (_) {}
    }

    if (resolvedName.isEmpty && email != null && email.isNotEmpty) {
      resolvedName = email.split('@').first;
    }

    if (resolvedName.isEmpty) {
      resolvedName = 'Cineza Member';
    }

    if (fbUser != null && resolvedName != 'Cineza Member' && fbUser.displayName != resolvedName) {
      try {
        await fbUser.updateDisplayName(resolvedName);
        await fbUser.reload();
      } catch (_) {}
    }

    // Sync to MySQL
    if (uid.isNotEmpty) {
      try {
        await _apiService.syncUser(
          firebaseUid: uid,
          username: resolvedName,
          email: email,
          phoneNumber: phoneNumber,
          authProvider: phoneNumber != null ? 'PHONE' : 'GOOGLE',
          profilePicUrl: photoUrl,
        );
      } catch (_) {}
    }

    // Update active session user
    final currentSession = currentUserNotifier.value;
    if (currentSession != null) {
      final updated = currentSession.copyWith(displayName: resolvedName);
      setSessionUser(updated);
    }

    return resolvedName;
  }

  /// Update the current user's username both in Firebase Auth and MySQL database
  Future<void> updateUsername(String newUsername) async {
    final cleanName = newUsername.trim();
    final fbUser = _auth.currentUser;
    if (fbUser != null) {
      try {
        await fbUser.updateDisplayName(cleanName);
        await fbUser.reload();
      } catch (_) {}

      try {
        await _apiService.syncUser(
          firebaseUid: fbUser.uid,
          username: cleanName,
          email: fbUser.email,
          phoneNumber: fbUser.phoneNumber,
          authProvider: fbUser.phoneNumber != null ? 'PHONE' : 'GOOGLE',
          profilePicUrl: fbUser.photoURL,
        );
      } catch (_) {}
    }

    final currentSession = currentUserNotifier.value;
    if (currentSession != null) {
      final updated = currentSession.copyWith(displayName: cleanName);
      setSessionUser(updated);

      if (fbUser == null) {
        try {
          await _apiService.syncUser(
            firebaseUid: updated.uid,
            username: cleanName,
            email: updated.email,
            phoneNumber: updated.phoneNumber,
            authProvider: updated.authProvider,
            profilePicUrl: updated.photoURL,
          );
        } catch (_) {}
      }
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    if (cred.user != null) {
      final cinezaUser = CinezaUser.fromFirebaseUser(cred.user!);
      setSessionUser(cinezaUser);
    }
    return cred;
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
    if (userCredential.user != null) {
      final cinezaUser = CinezaUser.fromFirebaseUser(
        userCredential.user!,
        overrideDisplayName: displayName,
      );
      setSessionUser(cinezaUser);
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

      final cred = await _auth.signInWithCustomToken(customToken);
      if (cred.user != null) {
        final cinezaUser = CinezaUser.fromFirebaseUser(cred.user!);
        setSessionUser(cinezaUser);
      }
      return cred;
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

    final cred = await _auth.signInWithCredential(credential);
    if (cred.user != null) {
      final cinezaUser = CinezaUser.fromFirebaseUser(cred.user!);
      setSessionUser(cinezaUser);
    }
    return cred;
  }

  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {}

    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}

    // Erase all user, location, and session-specific data across Cineza
    clearAllUserData();
  }

  /// Completely wipes all user, location, and session-specific data across Cineza
  static void clearAllUserData() {
    currentUserNotifier.value = null;

    // 1. Reset user's chosen location back to 'LOCATION'
    LocationService.clearCity();

    // 2. Refresh the API seat-locking session ID so no prior reservations leak
    ApiService.resetSession();

    // 3. Clear web sessionStorage and any cached auth/otp state
    clearWebSession();
    try {
      saveWebUserSession('');
    } catch (_) {}
  }
}
