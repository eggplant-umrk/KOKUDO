import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../data/auth_repository.dart';
import '../data/firestore_sync_repository.dart';
import '../theme/app_colors.dart';
import '../widgets/google_sign_in_button.dart';
import '../widgets/gradient_button.dart';

/// Firebase Authenticationによるログイン画面。
/// 現段階ではGoogleログインの導線のみを実装する（先行準備タスク）。
///
/// Web版はGoogle Identity Servicesの仕様上、アプリ側が用意したボタンから
/// authenticate()を呼ぶ方式が使えない（SDKが描画するボタン経由でのみ
/// サインインできる）ため、kIsWebで分岐し、Web版だけ
/// google_sign_in_webのrenderButton()を表示してauthenticationEventsを
/// 購読する方式にしている（PR #13レビュー指摘対応: Web版でログインボタンを
/// 押しても認証画面が開かず失敗していた不具合の修正）。
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthRepository _auth = AuthRepository.instance;
  bool _loading = false;
  bool _webButtonReady = false;
  String? _errorMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _webAuthEventsSubscription;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      _initWebSignIn();
    }
  }

  @override
  void dispose() {
    _webAuthEventsSubscription?.cancel();
    super.dispose();
  }

  /// Web版: SDK描画ボタンを表示する前に初期化し、サインインイベントの
  /// 購読を始める。
  Future<void> _initWebSignIn() async {
    await _auth.ensureInitialized();
    _webAuthEventsSubscription = _auth.authenticationEvents.listen(
      _handleWebAuthenticationEvent,
      onError: (Object _) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _errorMessage = 'ログインに失敗しました。時間をおいて再度お試しください。';
        });
      },
    );
    if (!mounted) return;
    setState(() => _webButtonReady = true);
  }

  /// Web版: SDK描画ボタンでユーザーがサインイン操作を完了したときに呼ばれる。
  Future<void> _handleWebAuthenticationEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      await _auth.signInWithGoogleUser(event.user);
      // サインインに成功すると、AuthGateがauthStateChangesを検知して
      // 自動的にメイン画面へ遷移する。
      unawaited(FirestoreSyncRepository.instance.syncNow());
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'ログインに失敗しました。時間をおいて再度お試しください。';
      });
    }
  }

  /// 非Web版（Android/iOS）: 従来どおりボタン押下でauthenticate()を呼ぶ。
  Future<void> _handleGoogleSignIn() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final credential = await _auth.signInWithGoogle();
      // サインインに成功すると、AuthGateがauthStateChangesを検知して
      // 自動的にメイン画面へ遷移する。キャンセル時はnullが返るのでここで
      // ローディングを解除するだけでよい。
      if (credential != null) {
        // 画面遷移をブロックしないよう、同期は待たずにバックグラウンドで実行する。
        unawaited(FirestoreSyncRepository.instance.syncNow());
      }
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'ログインに失敗しました。時間をおいて再度お試しください。';
      });
    }
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
                '国道ラン',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignInArea() {
    if (kIsWeb) {
      if (_loading || !_webButtonReady) {
        return const SizedBox(
          height: 54,
          child: Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.routeSignBlue),
            ),
          ),
        );
      }
      return SizedBox(height: 54, child: buildGoogleSignInButton());
    }

    return GradientButton(
      onPressed: _handleGoogleSignIn,
      height: 54,
      child: _loading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : const Row(
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
}