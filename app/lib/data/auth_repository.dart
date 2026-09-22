import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:meta/meta.dart';

/// Firebase Authenticationのラッパー。
///
/// 現段階ではGoogleログインの導線のみを実装する（先行準備タスク）。
/// Firestoreとの同期処理は別タスクで対応予定。
///
/// Web版では GoogleSignIn.instance.authenticate() が使えない（Google Identity
/// Servicesの仕様上、アプリ側が用意したボタンからのサインインは未対応で、
/// SDKが描画するボタン経由でのみサインインできる）ため、[ensureInitialized]・
/// [authenticationEvents]・[signInWithGoogleUser] をWeb版のログイン画面から
/// 個別に呼び出せるように公開している（PR #13レビュー指摘対応）。
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

  /// Web版のログイン画面で、SDK描画ボタン([signInWithGoogleUser]と組み合わせて
  /// 使う)を表示する前に呼ぶ。何度呼んでも安全（初期化済みなら何もしない）。
  Future<void> ensureInitialized() => _ensureGoogleSignInInitialized();

  /// このプラットフォームで[signInWithGoogle]（ボタン不要のサインイン）が
  /// 使えるかどうか。Web版ではfalseになる。
  bool get supportsButtonlessSignIn => _googleSignIn.supportsAuthenticate();

  /// Web版: SDKが描画するボタン経由のサインイン状態変化を通知するストリーム。
  Stream<GoogleSignInAuthenticationEvent> get authenticationEvents =>
      _googleSignIn.authenticationEvents;

  /// Googleアカウントでサインインする。ユーザーが選択ダイアログを
  /// キャンセルした場合はnullを返す。
  ///
  /// [supportsButtonlessSignIn]がfalseのプラットフォーム（Web）では使えない。
  /// Web版は代わりに[authenticationEvents]を購読し、SDK描画ボタンでの
  /// サインインイベントを[signInWithGoogleUser]に渡す。
  Future<UserCredential?> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }

    return signInWithGoogleUser(googleUser);
  }

  /// 既にGoogleアカウントの選択が済んだ[googleUser]を使ってFirebaseに
  /// サインインする。[signInWithGoogle]（非Web）と、Web版の
  /// [authenticationEvents]経由のサインインの両方から共通で使う。
  Future<UserCredential> signInWithGoogleUser(GoogleSignInAccount googleUser) async {
    final idToken = googleUser.authentication.idToken;
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    return _auth.signInWithCredential(credential);
  }

  /// 開発中の動作確認用: GoogleのOAuth設定(承認済みオリジン等)に依存せず
  /// ログインを完了させたい場合に使う匿名サインイン。
  Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  /// ログイン中のユーザーを Firebase Authentication から削除する。
  ///
  /// Firebase は最後のログインから時間が経っていると削除を
  /// `requires-recent-login` で拒否するので、その場合は Google アカウントの
  /// 選択ダイアログを出して再認証してからもう一度削除する。ユーザーが
  /// ダイアログをキャンセルしたときは [AccountDeletionCancelled] を投げる。
  /// Web版はボタン無しの再認証ができないため、その場合もこの例外にして
  /// 「一度ログアウトして入り直してから」と案内する。
  ///
  /// 成功すると authStateChanges が null を流し、AuthGate がログイン画面に戻す。
  Future<void> deleteCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code != 'requires-recent-login') rethrow;
      await _reauthenticateWithGoogle(user);
      await user.delete();
    }
    await _googleSignIn.signOut();
  }

  Future<void> _reauthenticateWithGoogle(User user) async {
    await _ensureGoogleSignInInitialized();
    if (!supportsButtonlessSignIn) throw const AccountDeletionCancelled(needsRelogin: true);

    final GoogleSignInAccount googleUser;
    try {
      googleUser = await _googleSignIn.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) throw const AccountDeletionCancelled();
      rethrow;
    }
    final credential = GoogleAuthProvider.credential(idToken: googleUser.authentication.idToken);
    await user.reauthenticateWithCredential(credential);
  }
}

/// アカウント削除の途中で、必要な再認証ができなかったことを表す。
/// [needsRelogin] が true のときは、この環境では再認証ダイアログを
/// 出せないので、ログアウト→再ログインしてからやり直してもらう。
class AccountDeletionCancelled implements Exception {
  final bool needsRelogin;

  const AccountDeletionCancelled({this.needsRelogin = false});
}