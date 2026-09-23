import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 地図マーカーの色の凡例（未走破／挑戦中／完走）。
/// 走破・地図コレクション画面のパネル下と、地図の全画面表示の両方で使う。
class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: const [BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 1)],
            ),
          ),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ],
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 14,
      children: [
        dot(AppColors.routeInactive, '未走破'),
        dot(AppColors.routeNeonBlue, '挑戦中'),
        dot(AppColors.accentGold, '完走'),
      ],
    );
  }
}
