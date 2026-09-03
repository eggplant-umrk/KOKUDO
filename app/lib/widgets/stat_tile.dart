import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// ラベル＋数値のミニ統計カード。ホーム画面の本日/今月の距離、地図画面の
/// サマリーバー、ランニング計測画面のペース／カロリー表示などで共用する。
class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final double valueFontSize;
  final bool centered;
  final bool dark;
  final EdgeInsetsGeometry padding;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.valueFontSize = 20,
    this.centered = false,
    this.dark = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = dark ? Colors.white.withValues(alpha: 0.5) : AppColors.textSecondary;
    final valueColor = dark ? Colors.white : AppColors.textPrimary;
    final bg = dark ? Colors.white.withValues(alpha: 0.06) : AppColors.bgSurfaceRaised;
    final borderColor = dark ? Colors.white.withValues(alpha: 0.14) : AppColors.borderSubtle;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            label,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: labelColor),
          ),
          SizedBox(height: centered ? 2 : 4),
          Text(
            value,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: valueFontSize, fontWeight: FontWeight.w900, color: valueColor),
          ),
        ],
      ),
    );
  }
}
