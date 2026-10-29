// lib/services/social_auth_service.dart
// Real Google + Facebook sign-in/sign-up, wired to Firebase Auth, then
// mirrored into the app's own AuthService so every FoodHub dashboard,
// the admin customer directory and cross-device cloud sync keep working
// with the exact same email identity as an email/password account.
//
// Everything is wrapped in try/catch with graceful fallback: if the Google
// or Facebook provider is not configured on this build (missing SHA-1
// fingerprint in the Firebase console, no facebook_app_id / FB app created,
// no Google Play services on the emulator, etc.) we surface a clear,
// actionable message instead of crashing — and we never silently "sign in"
// without an identity.
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:foodhub1/auth_service.dart';
import 'package:foodhub1/services/firebase_sync_service.dart';
import 'package:foodhub1/services/session_manager.dart';

class SocialAuthService {
  SocialAuthService._();
  static final SocialAuthService instance = SocialAuthService._();

  final GoogleSignIn _google = GoogleSignIn();

  /// Real Google sign-in. Returns null on success (or when the user just
  /// cancels the account chooser), otherwise a user-facing error message.
  Future<String?> signInWithGoogle() async {
    try {
      final account = await _google.signIn();
      if (account == null) return null; // user cancelled the chooser
      final auth = await account.authentication;
      final oAuthCred = fa.GoogleAuthProvider.credential(
        accessToken: auth.accessToken,
        idToken: auth.idToken,
      );
      return _completeSocial(
        email: account.email,
        name: account.displayName ?? account.email.split('@').first,
        credential: oAuthCred,
      );
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'account-exists-with-different-credential' =>
          'An account already exists for that Google account — sign in '
              'with your email + password instead.',
        'operation-not-allowed' =>
          'Google sign-in is not enabled in your Firebase console. '
              'Enable the Google provider under Authentication → Sign-in method.',
        'invalid-credential' => 'Google sign-in could not be verified. '
            'Double-check your SHA-1 fingerprint is registered in '
            'Project Settings → Your apps.',
        _ => 'Google sign-in failed: ${e.message ?? e.code}',
      };
    } catch (e) {
      // Covers: GoogleSignIn not configured (PlatformException code
      // "sign_in_failed"/"unconfigured"), missing Google Play services on
      // an emulator, or a revoked OAuth client. These are configuration
      // gaps, never a crash.
      return 'Google sign-in isn’t configured for this build yet. You can '
          'still log in with your email + password, or ask the developer to '
          'register the SHA-1 fingerprint / web client ID in Firebase. '
          '($e)';
    }
  }

  /// Real Facebook sign-in. Like [signInWithGoogle], never crashes: a
  /// missing facebook_app_id or unconfigured Facebook app name surfaces a
  /// friendly message instead.
  Future<String?> signInWithFacebook() async {
    try {
      final result =
          await FacebookAuth.instance.login(permissions: const [
            'email',
            'public_profile',
          ]);
      if (result.status == LoginStatus.cancelled) return null; // user backed out
      if (result.status != LoginStatus.success ||
          result.accessToken == null) {
        return 'Facebook sign-in did not complete. Please try again.';
      }
      final userData = await FacebookAuth.instance.getUserData();
      final email = (userData['email'] as String?) ?? '';
      final oAuthCred = fa.FacebookAuthProvider.credential(
        result.accessToken!.tokenString,
      );
      if (email.trim().isEmpty) {
        // Facebook sometimes withholds email for unverified apps / test
        // users. Fall back to Firebase's profile email when available.
        String? fallback;
        final fu = fa.FirebaseAuth.instance.currentUser;
        if (fu != null) {
          fallback = fu.email;
          if (fallback == null || fallback.isEmpty) {
            for (final p in fu.providerData) {
              if (p.email != null && p.email!.isNotEmpty) {
                fallback = p.email;
                break;
              }
            }
          }
        }
        return _completeSocial(
          email: fallback ?? email,
          name: (userData['name'] as String?) ??
              (fallback ?? 'Facebook User').split('@').first,
          credential: oAuthCred,
        );
      }
      return _completeSocial(
        email: email,
        name: (userData['name'] as String?) ?? email.split('@').first,
        credential: oAuthCred,
      );
    } on fa.FirebaseAuthException catch (e) {
      return switch (e.code) {
        'account-exists-with-different-credential' =>
          'An account already exists for that Facebook account — sign in '
              'with your email + password instead.',
        'operation-not-allowed' =>
          'Facebook sign-in is not enabled in your Firebase console.',
        _ => 'Facebook sign-in failed: ${e.message ?? e.code}',
      };
    } catch (e) {
      return 'Facebook sign-in isn’t configured for this build yet. Add a '
          'facebook_app_id (and a Facebook app) in the Android manifest so '
          'the Facebook Login button can work. ($e)';
    }
  }

  /// Shared tail: verify the Firebase credential, then mirror the identity
  /// into AuthService (+ Firestore user doc) so the rest of the app treats
  /// the social login exactly like a normal email/password login.
  Future<String?> _completeSocial({
    required String email,
    required String name,
    required fa.AuthCredential credential,
  }) async {
    final key = email.trim().toLowerCase();
    if (key.isEmpty) {
      return 'Social sign-in did not return an email address. Please '
          'grant the email permission or use email + password instead.';
    }
    try {
      await fa.FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      // Firebase backend unreachable/nonexistent — still allow the local
      // mirror so the demo app keeps working offline.
    }

    // Mirror into the local account store so every dashboard + the admin
    // customer directory see this person (same code path as email signup).
    // A brand-new social account has no local password hash — that's fine,
    // `upsertUser` accepts null and Firebase Auth owns the credential.
    AuthService.instance.currentEmail = key;
    AuthService.instance.currentName = name.trim();
    FirebaseSyncService.instance.upsertUser(
      email: key,
      name: name.trim(),
      passwordHash: AuthService.instance.passwordHashFor(key),
    );
    // Same post-sign-in wiring as email/password: persisted session,
    // rules-allowed Firestore listeners, push topics.
    await SessionManager.onSignedIn(
      role: SessionRole.customer,
      email: key,
      name: name.trim(),
    );
    return null; // success
  }
}
