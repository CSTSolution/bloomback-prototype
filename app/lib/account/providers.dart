// Sign in with Apple and Google sign-in on the phone. Each returns the provider's ID token (checked again by our
// server) or null when the person cancelled. Behind an interface so tests and the web demo never open a sheet.
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Google OAuth client ids (public by design, not secrets). Project "CST Apps 2".
/// Made 2026-11-14: web "BloomBack server", iOS "BloomBack iOS", Android (upload key + this Mac's debug key);
/// the Play app-signing key's SHA-1 still needs its own Android client once the Play app exists.
const kGoogleIosClientId = String.fromEnvironment('BB_GOOGLE_IOS_CLIENT', defaultValue: '132091061385-8rd2qvt7mi5jem5u4b94nsn4s2m686rh.apps.googleusercontent.com');
const kGoogleWebClientId = String.fromEnvironment('BB_GOOGLE_WEB_CLIENT', defaultValue: '132091061385-v9gn7ofhlu7i7qmr36nm7ri18esvimsm.apps.googleusercontent.com');

class ProviderToken {
  const ProviderToken(this.idToken, {this.name});
  final String idToken;
  final String? name; // first name, when the provider gives one (Apple only the first time)
}

class ProviderTrouble implements Exception {
  const ProviderTrouble(this.words);
  final String words;
  @override
  String toString() => words;
}

abstract class SignInProviders {
  bool get appleAvailable;
  bool get googleAvailable;
  Future<ProviderToken?> apple();
  Future<ProviderToken?> google();
}

class DeviceSignInProviders implements SignInProviders {
  bool _googleReady = false;

  bool get _ios => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Sign in with Apple on iPhone only (on Android it needs a web flow we do not run).
  @override
  bool get appleAvailable => _ios;

  @override
  bool get googleAvailable => kGoogleWebClientId.isNotEmpty && (_android || (_ios && kGoogleIosClientId.isNotEmpty));

  @override
  Future<ProviderToken?> apple() async {
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
      );
      final token = c.identityToken;
      if (token == null) throw const ProviderTrouble('Apple did not confirm the sign-in. Try again.');
      return ProviderToken(token, name: c.givenName);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw const ProviderTrouble('Sign in with Apple did not finish. Try again.');
    }
  }

  @override
  Future<ProviderToken?> google() async {
    if (!googleAvailable) throw const ProviderTrouble('Google sign-in is not ready yet. Use email or Apple for now.');
    final g = GoogleSignIn.instance;
    try {
      if (!_googleReady) {
        await g.initialize(clientId: _ios ? kGoogleIosClientId : null, serverClientId: kGoogleWebClientId);
        _googleReady = true;
      }
      final acct = await g.authenticate(scopeHint: const ['email']);
      final token = acct.authentication.idToken;
      if (token == null) throw const ProviderTrouble('Google did not confirm the sign-in. Try again.');
      return ProviderToken(token, name: acct.displayName?.split(' ').first);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled || e.code == GoogleSignInExceptionCode.interrupted) return null;
      throw const ProviderTrouble('Google sign-in did not finish. Try again.');
    }
  }

  Future<void> signOutGoogle() async {
    if (_googleReady) await GoogleSignIn.instance.signOut();
  }
}

/// Tests and the web demo: no provider sheets.
class NoSignInProviders implements SignInProviders {
  const NoSignInProviders();
  @override
  bool get appleAvailable => false;
  @override
  bool get googleAvailable => false;
  @override
  Future<ProviderToken?> apple() async => null;
  @override
  Future<ProviderToken?> google() async => null;
}
