import 'package:flutter/material.dart';

/// アプリ全体のカラーパレット・寸法トークン。
/// 元のWebプロトタイプ（src/styles/global.css の :root）から移植。
class AppColors {
  AppColors._();

  // ベース背景
  static const bgAppTop = Color(0xFFCDF1FF);
  static const bgAppBottom = Color(0xFFFFFFFF);
  static const bgSurface = Color(0xFFFFFFFF);
  static const bgSurfaceRaised = Color(0xFFF3FAFD);

  // アクセントカラー
  static const accentBlue = Color(0xFF2AA7E0);
  static const accentBlueDark = Color(0xFF1C86BD);
  static const accentGreen = Color(0xFF34C98A);
  static const accentGold = Color(0xFFFFB238);
  static const accentGoldText = Color(0xFFB4720A);

  // 実際の国道標識と同じ青（キャラクターの標識アセットから採取）
  static const routeSignBlue = Color(0xFF22588E);
  static const routeSignBlueLight = Color(0xFF2F74B8);
  static const routeSignBlueDark = Color(0xFF173F66);

  static const textPrimary = Color(0xFF1C2B36);
  static const textSecondary = Color(0xFF5C6F7D);
  static const textTertiary = Color(0xFF92A3AE);
  static const borderSubtle = Color(0xFFE1EEF5);
  static const routeInactive = Color(0xFFCFDBE2);
  // 走破・地図コレクション画面の地図マーカー用ネオンブルー（挑戦中）
  static const routeNeonBlue = Color(0xFF2FA9FF);
  static const danger = Color(0xFFE4536A);
  static const dangerBg = Color(0x1AE4536A); // rgba(228,83,106,0.1)
  static const dangerBgOnDark = Color(0x2EE4536A); // rgba(228,83,106,0.18)

  // Googleマップ風の地図パネル配色
  static const mapWaterTop = Color(0xFFA9DEF2);
  static const mapWaterMid = Color(0xFFC3E7F5);
  static const mapWaterBottom = Color(0xFFD9EFF8);
  static const mapWaterBorder = Color(0xFF93CFE9);
  static const mapLand = Color(0xFFF4EFE2);
  static const mapLandBorder = Color(0xFFD9D0B4);
  static const mapLabel = Color(0xFF3C4043);

  static const radiusSm = 12.0;
  static const radiusMd = 20.0;
  static const radiusLg = 28.0;
  static const radiusFull = 999.0;

  static const routeSignGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [routeSignBlueLight, routeSignBlue],
  );
}
