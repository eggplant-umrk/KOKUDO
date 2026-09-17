import 'dart:ui';

import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import '../models/national_route.dart';
import '../theme/app_colors.dart';
import 'goal_speech_bubble.dart';

/// ホーム画面のキャラクター走行アニメーション領域。
/// 背景はいただいた国道の走路イラスト（road-bg.webp／ループ動画）を、
/// 縦長に画面いっぱいに敷いている。路線名・区間・設定ボタンは動画の上に
/// ポップアップするチップとして重ね、完走ナビ（逆算計算）はキャラクターの
/// セリフ（吹き出し）として表示する。
/// キャラクター（character-run.webp）は手前に大きく、足元を接地させて配置。
/// 読み込みに失敗した場合は元のGIF、それも失敗した場合はフォールバック表示に切り替える。
class HeroStage extends StatelessWidget {
  final NationalRoute route;
  final double currentDistanceKm;
  final DateTime targetEndDate;
  final int? runsPerWeekGoal;
  final ValueChanged<DateTime> onChangeTargetEndDate;
  final ValueChanged<int?> onChangeRunsPerWeekGoal;
  final VoidCallback onOpenHistory;
  final VoidCallback onChangeRoute;
  final String passedLandmark; // 例: "42.0km地点｜小田原市"
  final String nextCheckpointLabel; // 例: "箱根峠まであと 12.4km"
  final int streakDays; // 連続記録日数(ストリーク)。0の場合はバッジを表示しない。

  const HeroStage({
    super.key,
    required this.route,
    required this.currentDistanceKm,
    required this.targetEndDate,
    required this.runsPerWeekGoal,
    required this.onChangeTargetEndDate,
    required this.onChangeRunsPerWeekGoal,
    required this.onOpenHistory,
    required this.onChangeRoute,
    required this.passedLandmark,
    required this.nextCheckpointLabel,
    this.streakDays = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _buildRoadBackground(),
                // 注: ノッチ／ステータスバーの回避は、常に画面最上部に表示される
                // ルートシェルのdev-navが既に確保しているため、ここではSafeAreaを
                // 重ねて二重にパディングしない。
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _routeBadge(),
                            const Spacer(),
                            _historyButton(context),
                            const SizedBox(width: 8),
                            _settingsButton(context),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _addressChip(),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 92,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.82,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: GoalSpeechBubble(
                          route: route,
                          currentDistanceKm: currentDistanceKm,
                          targetEndDate: targetEndDate,
                          runsPerWeekGoal: runsPerWeekGoal,
                          onChangeTargetEndDate: onChangeTargetEndDate,
                          onChangeRunsPerWeekGoal: onChangeRunsPerWeekGoal,
                        ),
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    heightFactor: 0.78,
                    child: _buildCharacter(),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (streakDays > 0)
                _chip(Icons.local_fire_department, '$streakDays日連続', gold: true),
              _chip(Icons.location_on, passedLandmark),
              _chip(Icons.flag, nextCheckpointLabel, gold: true),
            ],
          ),
        ),
      ],
    );
  }

  /// 走路の背景イラスト。road-bg.webpはGIF版(11.4MB)を同内容のまま
  /// WebPに変換して軽量化したもの(約2.7MB)。読み込みに失敗した場合は
  /// 元のGIF、それも失敗した場合はグラデーションのフォールバック表示に切り替える。
  Widget _buildRoadBackground() {
    return Image.asset(
      'assets/road-bg.webp',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.44), // object-position: 50% 28% 相当
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/road-bg.gif',
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.44),
          errorBuilder: (context, error, stackTrace) => _roadBackgroundFallback(),
        );
      },
    );
  }

  Widget _roadBackgroundFallback() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.routeSignBlue, AppColors.bgSurface],
        ),
      ),
    );
  }

  // 注: character-run.gif はdisposal method 2(前フレームを背景色で復元してから
  // 描画)を使っており、Flutter(Skia)のGIFデコーダがこのパターンで最初の1コマ
  // から進まない不具合があるため、アニメーションが再生されなかった。
  // 同じ内容をアニメーションWebPに変換した character-run.webp を優先的に使用し、
  // 万一読み込みに失敗した場合のみ元のGIF、それも失敗したらフォールバック表示。
  Widget _buildCharacter() {
    return Image.asset(
      'assets/character-run.webp',
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/character-run.gif',
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          errorBuilder: (context, error, stackTrace) => _characterFallback(),
        );
      },
    );
  }

  Widget _characterFallback() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.routeSignGradient,
            ),
            child: const Icon(Icons.play_arrow, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          const Text('走行アニメーション再生中…', style: TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _routeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.routeSignBlue,
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        boxShadow: const [BoxShadow(color: Color(0x590A1E37), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Text(
        route.name,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
      ),
    );
  }

  /// ラン履歴・カレンダー画面を直接開くボタン(設定ボタンの隣に配置)。
  Widget _historyButton(BuildContext context) {
    return GestureDetector(
      onTap: onOpenHistory,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            color: Colors.white.withValues(alpha: 0.88),
            child: const Icon(Icons.calendar_month, size: 18, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  Widget _settingsButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSettingsSheet(context),
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            color: Colors.white.withValues(alpha: 0.88),
            child: const Icon(Icons.settings, size: 18, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }

  /// 設定ボトムシート。現段階では「ルート変更」「ログアウト」のみを置く簡易版。
  /// 「挑戦する国道を変更」は[onChangeRoute]経由でChangeRouteScreenを開く。
  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusLg)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '設定',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: const Icon(Icons.alt_route, color: AppColors.textSecondary),
                title: const Text('挑戦する国道を変更', style: TextStyle(fontWeight: FontWeight.w700)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  onChangeRoute();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: const Text(
                  'ログアウト',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  AuthRepository.instance.signOut();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Widget _addressChip() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppColors.radiusFull),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: const Color(0x66142236),
          child: Text(
            '${route.startPoint.label ?? ''} 〜 ${route.endPoint.label ?? ''}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              shadows: [Shadow(color: Color(0x59000000), blurRadius: 3, offset: Offset(0, 1))],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label, {bool gold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: gold ? const Color(0x24FFB238) : AppColors.bgSurfaceRaised,
        border: Border.all(color: gold ? const Color(0x4DFFB238) : AppColors.borderSubtle),
        borderRadius: BorderRadius.circular(AppColors.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: gold ? AppColors.accentGold : AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: gold ? AppColors.accentGoldText : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
