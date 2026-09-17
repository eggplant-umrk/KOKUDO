import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/auth_repository.dart';
import '../data/firestore_sync_repository.dart';
import '../data/google_signin_web.dart' as google_web_button;
import '../theme/app_colors.dart';
import '../widgets/gradient_button.dart';

/// Firebase Authenticationによるログイン画面。
/// 現段階ではGoogleログインの導線のみを実装する（先行準備タスク）。
///
/// 注意: google_sign_in v7ではWeb上でauthenticate()が使えないため
/// (UnimplementedErrorになる)、Web版はGoogleが提供するボタン
/// (renderButton)を直接表示してクリックしてもらう方式にしている。
/// モバイル(iOS/Android)版は従来通り独自デザインのボタンを使う。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthRepository _auth = AuthRepository.instance;
  bool _loading = false;
  bool _googleReady = false;
  String? _errorMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authEventsSub;

  @override
  void initState() {
    super.initState();
    _initGoogleSignIn();
  }

  Future<void> _initGoogleSignIn() async {
    try {
      await _auth.ensureGoogleSignInInitialized();
      if (kIsWeb) {
        // Web版はGoogleが提供するボタンのクリック結果をこのストリームで受け取る。
        _authEventsSub = _auth.googleAuthenticationEvents.listen(
          _handleGoogleAuthenticationEvent,
          onError: (Object e, StackTrace st) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _errorMessage = 'ログインに失敗しました。時間をおいて再度お試しください。';
            });
          },
        );
      }
      if (mounted) setState(() => _googleReady = true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _googleReady = true;
        _errorMessage = 'ログイン機能の初期化に失敗しました。時間をおいて再度お試しください。';
      });
    }
  }

  @override
  void dispose() {
    _authEventsSub?.cancel();
    super.dispose();
  }

  /// Web版: Googleが提供するボタンがクリックされたときに呼ばれる。
  Future<void> _handleGoogleAuthenticationEvent(
    GoogleSignInAuthenticationEvent event,
  ) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      await _auth.signInWithGoogleAccount(event.user);
      // サインインに成功すると、AuthGateがauthStateChangesを検知して
      // 自動的にメイン画面へ遷移する。
      unawaited(FirestoreSyncRepository.instance.syncNow());
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'ログインに失敗しました。時間をおいて再度お試しください。';
      });
    }
  }

  /// 開発中の動作確認用: GoogleのOAuth「承認済みオリジン」設定に阻まれて
  /// Web版のログインが通らない場合の抜け道。匿名サインインでAuthGateを
  /// 通過し、機能そのもの(今回は完走エフェクトなど)の確認に進めるようにする。
  Future<void> _handleAnonymousSignIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _auth.signInAnonymously();
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage =
            '匿名ログインに失敗しました。Firebaseコンソールの Authentication → Sign-in method で '
            'Anonymous を有効化してください。';
      });
    }
  }

  /// モバイル(iOS/Android)版: 独自ボタンから直接呼び出す。
  Future<void> _handleGoogleSignIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final credential = await _auth.signInWithGoogle();
      if (credential != null) {
        unawaited(FirestoreSyncRepository.instance.syncNow());
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'ログインに失敗しました。時間をおいて再度お試しください。';
      });
    }
  }

  Widget _buildSignInArea() {
    if (_loading) {
      return const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.textPrimary),
      );
    }

    if (kIsWeb) {
      if (!_googleReady) {
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.textPrimary),
        );
      }
      return SizedBox(
        height: 44,
        child: google_web_button.buildGoogleRenderedSignInButton(),
      );
    }

    return GradientButton(
      onPressed: _handleGoogleSignIn,
      height: 54,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.login, color: Colors.white, size: 20),
          SizedBox(width: 8),
          Text(
            'Googleでログイン',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.routeSignGradient,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.directions_run, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 20),
              const Text(
                'KOKUDO',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                '国道完走チャレンジアプリ',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 40),
              _buildSignInArea(),
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ],
              // Web版でGoogleログインがOAuthオリジン設定などに阻まれる場合の
              // 開発用の抜け道（実プロダクトのUIには含まれない）。
              // kDebugModeでガードし、本番(リリース)ビルドには出さない。
              if (kIsWeb && kDebugMode && !_loading) ...[
                const SizedBox(height: 20),
                TextButton(
                  onPressed: _handleAnonymousSignIn,
                  child: const Text(
                    'ゲストで続ける(開発確認用)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}