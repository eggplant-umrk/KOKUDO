import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 汎用の横長プログレスバー。単色 (fillColor) かグラデーション (fillGradient)
/// のどちらか一方を指定する。
class AppProgressBar extends StatelessWidget {
  final double ratio; // 0..1
  final double height;
  final Color trackColor;
  final Color? fillColor;
  final Gradient? fillGradient;
  final BorderRadiusGeometry? borderRadius;

  const AppProgressBar({
    super.key,
    required this.ratio,
    this.height = 8,
    this.trackColor = const Color(0xFFE3EEF3),
    this.fillColor,
    this.fillGradient,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final pct = ratio.clamp(0.0, 1.0).toDouble();
    final radius = borderRadius ?? BorderRadius.circular(AppColors.radiusFull);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        height: height,
        color: trackColor,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: pct,
          child: Container(
            decoration: BoxDecoration(
              color: fillGradient == null ? (fillColor ?? AppColors.routeSignBlue) : null,
              gradient: fillGradient,
            ),
          ),
        ),
      ),
    );
  }
}
