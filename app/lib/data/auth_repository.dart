import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';

/// Firebase Authenticationのラッパー。
///
/// 現段階ではGoogleログインの導線のみを実装する（先行準備タスク）。
/// Firestoreとの同期処理は別タスクで対応予定。
class AuthRepository {
  AuthRepository._({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _auth = auth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  static AuthRepository instance = AuthRepository._();

  @visibleForTesting
  factory AuthRepository.forTesting({FirebaseAuth? auth, GoogleSignIn? googleSignIn}) {
    return AuthRepository._(auth: auth, googleSignIn: googleSignIn);
  }

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  bool _googleSignInInitialized = false;

  User? get currentUser => _auth.currentUser;

  /// ログイン状態の変化を監視するストリーム。AuthGateがこれを購読して
  /// ログイン画面／メイン画面を自動的に切り替える。
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  /// Googleアカウントでサインインする。ユーザーが選択ダイアログを
  /// キャンセルした場合はnullを返す。
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
