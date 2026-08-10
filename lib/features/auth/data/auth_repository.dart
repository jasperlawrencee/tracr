import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

final authStateChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(firebaseAuthProvider).authStateChanges();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(googleSignInProvider),
  );
});

class AuthRepository {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  AuthRepository(this._auth, this._googleSignIn) {
    // On web, google_sign_in has no imperative authenticate() call; sign-in
    // instead comes through this event stream from the rendered GSI button.
    _googleSignIn.authenticationEvents.listen(_onGoogleAuthEvent);
  }

  User? get currentUser => _auth.currentUser;

  Future<void> _onGoogleAuthEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is GoogleSignInAuthenticationEventSignIn) {
      final credential = GoogleAuthProvider.credential(
        idToken: event.user.authentication.idToken,
      );
      await _auth.signInWithCredential(credential);
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await sendVerificationEmail();
  }

  Future<void> sendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// `emailVerified` is cached on the local [User] and neither
  /// authStateChanges() nor idTokenChanges() emit when it flips server-side,
  /// so callers must poll this explicitly. Also refreshes the ID token,
  /// since `email_verified` is a token claim Firestore rules read — a stale
  /// token still reads false there even after this returns true.
  Future<bool> refreshEmailVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) await _auth.currentUser!.getIdToken(true);
    return verified;
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}