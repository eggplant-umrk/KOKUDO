import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/route_models.dart';
import 'screens/home_screen.dart';
import 'screens/map_collection_screen.dart';
import 'screens/running_screen.dart';
import 'theme/app_colors.dart';

class KokudoRunApp extends StatelessWidget {
  const KokudoRunApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '国道ラン - 国道完走チャレンジ',
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
      home: const RootShell(),
    );
  }
}

enum _ScreenKey { home, running, map }

const Map<_ScreenKey, String> _screenLabel = {
  _ScreenKey.home: '① ホーム',
  _ScreenKey.running: '② ランニング計測',
  _ScreenKey.map: '③ 走破・地図',
};

/// デモ用の画面切り替えナビ付きのルートシェル。
/// dev-nav（画面切り替えタブ）は実プロダクトのUIには含まれない開発用の仕組み。
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  _ScreenKey _screen = _ScreenKey.home;
  RunResult? _lastResult;

  void _goTo(_ScreenKey key) => setState(() => _screen = key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgSurface,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: _buildDevNav(),
            ),
          ),
          Expanded(child: _buildActiveScreen()),
          if (_lastResult != null && _screen == _ScreenKey.home)
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '直近のラン: ${_lastResult!.distanceKm.toStringAsFixed(2)}km / '
                  '${_lastResult!.caloriesBurned}kcal を記録しました',
                  style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDevNav() {
    return Row(
      children: _ScreenKey.values.map((key) {
        final active = key == _screen;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => _goTo(key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  gradient: active ? AppColors.routeSignGradient : null,
                  color: active ? null : Colors.white,
                  border: active ? null : Border.all(color: AppColors.borderSubtle),
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                alignment: Alignment.center,
                child: Text(
                  _screenLabel[key]!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActiveScreen() {
    switch (_screen) {
      case _ScreenKey.home:
        return HomeScreen(onStartRunning: () => _goTo(_ScreenKey.running));
      case _ScreenKey.running:
        return RunningScreen(
          onFinish: (result) {
            setState(() {
              _lastResult = result;
              _screen = _ScreenKey.home;
            });
          },
        );
      case _ScreenKey.map:
        return const MapCollectionScreen();
    }
  }
}
