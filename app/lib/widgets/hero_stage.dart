import 'dart:ui';

import 'package:flutter/material.dart';

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
  final String passedLandmark; // 例: "42.0km地点｜小田原市"
  final String nextCheckpointLabel; // 例: "箱根峠まであと 12.4km"

  const HeroStage({
    super.key,
    required this.route,
    required this.currentDistanceKm,
    required this.targetEndDate,
    required this.runsPerWeekGoal,
    required this.onChangeTargetEndDate,
    required this.onChangeRunsPerWeekGoal,
    required this.passedLandmark,
    required this.nextCheckpointLabel,
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
                            _settingsButton(),
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
              _chip(Icons.location_on, passedLandmark),
              _chip(Icons.flag, nextCheckpointLabel, gold: true),
            ],
          ),
        ),
      ],
    );
  }

  /// 走路の背景イラスト。画像が未コミット・読み込み失敗の場合は、
  /// キャラクター画像と同様にグラデーションのフォールバック表示に切り替える。
  Widget _buildRoadBackground() {
    return Image.asset(
      'assets/road-bg.webp',
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.44), // object-position: 50% 28% 相当
      errorBuilder: (context, error, stackTrace) => _roadBackgroundFallback(),
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

  Widget _settingsButton() {
    return ClipOval(
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
