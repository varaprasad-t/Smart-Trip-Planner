import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _google = GoogleSignIn.instance;
  bool _initialized = false;

  Future<void> _initGoogle(String webClientId) async {
    if (!_initialized) {
      await _google.initialize(serverClientId: webClientId);
      _initialized = true;
    }
  }

  Future<User?> signUpWithEmailAndPassword(String email, String password) =>
      _auth
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .then((c) => c.user);

  Future<User?> signInWithEmailAndPassword(String email, String password) =>
      _auth
          .signInWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          )
          .then((c) => c.user);

  Future<User?> signInWithGoogle({required String webClientId}) async {
    await _initGoogle(webClientId);

    GoogleSignInAccount? account;
    if (_google.supportsAuthenticate()) {
      account = await _google.authenticate(scopeHint: ['email']);
    } else {
      // fallback scenario — in practice authenticate is supported on Android/iOS
      account = null;
    }

    if (account == null) return null;

    final authentication = await account.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: authentication.idToken,
    );
    final result = await _auth.signInWithCredential(credential);
    return result.user;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    await _google.signOut();
  }
}
