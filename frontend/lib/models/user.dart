import 'package:firebase_auth/firebase_auth.dart' show User;

/// Cineza User model representing the authenticated user across Firebase, Phone OTP, and MySQL
class CinezaUser {
  final String uid;
  final String? displayName;
  final String? email;
  final String? phoneNumber;
  final String? photoURL;
  final String authProvider; // 'GOOGLE', 'PHONE', 'EMAIL'

  /// Friendly username or display name accessor
  String get username => displayName ?? '';

  const CinezaUser({
    required this.uid,
    this.displayName,
    this.email,
    this.phoneNumber,
    this.photoURL,
    this.authProvider = 'PHONE',
  });

  CinezaUser copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? phoneNumber,
    String? photoURL,
    String? authProvider,
  }) {
    return CinezaUser(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoURL: photoURL ?? this.photoURL,
      authProvider: authProvider ?? this.authProvider,
    );
  }

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
        'phoneNumber': phoneNumber,
        'photoURL': photoURL,
        'authProvider': authProvider,
      };

  factory CinezaUser.fromJson(Map<String, dynamic> json) => CinezaUser(
        uid: json['uid'] as String? ?? '',
        displayName: json['displayName'] as String?,
        email: json['email'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        photoURL: json['photoURL'] as String?,
        authProvider: json['authProvider'] as String? ?? 'PHONE',
      );

  factory CinezaUser.fromFirebaseUser(User user, {String? overrideDisplayName}) {
    String resolvedName = overrideDisplayName ?? '';
    if (resolvedName.isEmpty &&
        user.displayName != null &&
        user.displayName!.trim().isNotEmpty &&
        user.displayName != 'Cineza User') {
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
    if (resolvedName.isEmpty && user.email != null && user.email!.isNotEmpty) {
      resolvedName = user.email!.split('@').first;
    }
    if (resolvedName.isEmpty) {
      resolvedName = 'Cineza Member';
    }

    String provider = 'EMAIL';
    if (user.providerData.any((p) => p.providerId.contains('google'))) {
      provider = 'GOOGLE';
    } else if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) {
      provider = 'PHONE';
    }

    return CinezaUser(
      uid: user.uid,
      displayName: resolvedName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      photoURL: user.photoURL,
      authProvider: provider,
    );
  }
}

