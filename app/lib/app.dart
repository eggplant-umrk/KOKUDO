import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'data/auth_repository.dart';
import 'data/firestore_sync_repository.dart';
import 'data/route_repository.dart';
import 'models/run_log.dart';
import 'screens/change_route_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/map_collection_screen.dart';
import 'screens/run_history_screen.dart';
import 'screens/running_screen.dart';
import 'theme/app_colors.dart';

class KokudoRunApp extends StatelessWidget {
  const KokudoRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KOKUDO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgSurface,
        fontFamily: GoogleFonts.notoSansJp().fontFamily,
        textTheme: GoogleFonts.notoSansJpTextTheme(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.routeSignBlue,
          primary: AppColors.routeSignBlue,
        ),
      ),
      home: const AuthGate(),
    );
  }
}

/// ログイン状態に応じてログイン画面／メイン画面を切り替えるゲート。
/// Firebase Authenticationのログイン状態（authStateChanges）を監視する。
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      initialData: AuthRepository.instance.currentUser,
      stream: AuthRepository.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.bgSurface,
            body: Center(child: CircularProgressIndicator(color: AppColors.routeSignBlue)),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const RouteSetupGate();
      },
    );
  }
}

/// 挑戦する国道が決まるまで、本体(ボトムナビ)の代わりに選択画面を出すゲート。
///
/// デモデータの初期投入を取りやめたため、初めてログインした人は挑戦中の
/// 国道を1つも持っていない。何も選ばれていないまま本体を出すと、ホームに
/// 出すものが無い。そこでここで先に選んでもらう。
///
/// 一度選べば app_settings に残るので、次回以降はこのゲートを素通りする。
/// 挑戦していた路線を完走して次が未選択になった場合は、起動し直したときに
/// ここへ来る(アプリを開いたままなら、ホーム画面側が選び直しを促す)。
class RouteSetupGate extends StatefulWidget {
  const RouteSetupGate({super.key});

  @override
  State<RouteSetupGate> createState() => _RouteSetupGateState();
}

class _RouteSetupGateState extends State<RouteSetupGate> {
  bool _loading = true;
  bool _hasActiveRoute = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  /// クラウドからの取り込みを待つ上限。
  ///
  /// 圏外だと Firestore の読み書きはオンラインに戻るまで終わらないので、
  /// 待ちっぱなしにはしない。時間切れのときは端末内の記録だけで判断する。
  static const Duration _syncWaitLimit = Duration(seconds: 8);

  /// クラウドからの取り込みを待ってから、挑戦中の国道があるか判断する。
  ///
  /// ログイン画面が投げた同期と競争すると、クラウドに進捗があるのに
  /// 「未選択」と判断して、機種変更・再インストールの人にまで選択画面を
  /// 出してしまう。しかもそこで選んだ内容は明示的な選択として保存される
  /// ため、あとから届いた本来の進捗より優先されてしまう。
  Future<void> _check() async {
    try {
      await FirestoreSyncRepository.instance.syncNow().timeout(_syncWaitLimit);
    } catch (_) {
      // 同期できなくても、端末内の記録だけで判断して先へ進める。
    }
    final routeId = await RouteRepository.instance.getActiveRouteId();
    if (!mounted) return;
    setState(() {
      _hasActiveRoute = routeId != null;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.bgSurface,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.routeSignBlue),
              SizedBox(height: 16),
              Text(
                '記録を読み込んでいます…',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }
    if (!_hasActiveRoute) {
      return ChangeRouteScreen(
        firstRun: true,
        onSelected: () => setState(() => _hasActiveRoute = true),
      );
    }
    return const RootShell();
  }
}

/// ボトムナビのタブ。並び順がそのままタブの並びになる。
enum _Tab { home, running, history, map }

/// 4画面をボトムナビゲーションで切り替えるルートシェル。
///
/// リリース前修正項目 1-3: 開発用の画面切り替えタブ(dev-nav)・同期ボタン・
/// ログアウトボタンを取り除き、製品としてのボトムナビに置き換えた。
/// ログアウトはホーム画面の設定シートから、Firestore同期はログイン時と
/// 計測終了時に自動で行う。
///
/// ラン履歴はホーム画面右上のカレンダーボタンから開いていたが、見出しが
/// 窮屈だったのでタブに移した。タブを離れるとホーム画面は破棄されるため、
/// 履歴で記録を直して戻ると、作り直されたホーム画面が進捗を読み直す。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  _Tab _tab = _Tab.home;

  /// 計測画面を生かしたままにしておくかどうか。
  /// 一度「計測」タブを開いたらtrueになり、計測を終えるとfalseに戻る。
  bool _runningMounted = false;

  void _goTo(_Tab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      if (tab == _Tab.running) _runningMounted = true;
    });
  }

  void _handleRunFinished(RunResult result) {
    setState(() {
      _tab = _Tab.home;
      // 計測が完了したので計測画面は破棄する。次にタブを開いたときは
      // 新しい計測として作り直される。
      _runningMounted = false;
    });
    // 走った分をクラウドにも反映する。失敗しても次回ログイン時に再同期される
    // ので、ここでは待たない。
    unawaited(FirestoreSyncRepository.instance.syncNow());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${result.distanceKm.toStringAsFixed(2)}km / ${result.caloriesBurned}kcal を記録しました',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      // ノッチ／ステータスバーの回避はここで一括して行う(各画面は上側の
      // SafeArea を持たない前提で作られている)。下側はボトムナビが確保する。
      body: SafeArea(bottom: false, child: _buildActiveScreen()),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: const Color(0x1F22588E),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: selected ? AppColors.routeSignBlue : AppColors.textTertiary,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: selected ? AppColors.routeSignBlue : AppColors.textTertiary,
          );
        }),
      ),
      child: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) => _goTo(_Tab.values[index]),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'ホーム',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run),
            label: '計測',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '記録',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: '地図',
          ),
        ],
      ),
    );
  }

  /// 表示中の画面を組み立てる。
  ///
  /// 計測画面だけは、他のタブに切り替えてもウィジェットツリーから外さない。
  /// 外すと State が破棄され、dispose() で位置ストリームの購読が切れて
  /// フォアグラウンドサービスごと計測が止まってしまうため、Offstage で
  /// 画面外に退避させたまま生かしておく。
  ///
  /// 子の並び順は常に「0番目=ホーム/地図、1番目=計測画面」で固定する。
  /// 並びが変わると Element が作り直され、State を保持する意味が無くなる。
  Widget _buildActiveScreen() {
    return Stack(
      fit: StackFit.expand,
      children: [
        switch (_tab) {
          _Tab.home => HomeScreen(onStartRunning: () => _goTo(_Tab.running)),
          _Tab.history => const RunHistoryScreen(),
          _Tab.map => const MapCollectionScreen(),
          // 計測画面は下の Offstage 側が持つので、ここは場所だけ空けておく。
          _Tab.running => const SizedBox.shrink(),
        },
        if (_runningMounted)
          Offstage(
            key: const ValueKey('running-screen'),
            offstage: _tab != _Tab.running,
            child: RunningScreen(
              onFinish: _handleRunFinished,
              // 退避中に挑戦する国道が変更されることがあるため、
              // 再表示されたタイミングを計測画面側に伝える。
              isActive: _tab == _Tab.running,
            ),
          ),
      ],
    );
  }
}
