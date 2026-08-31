import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 国道標識ブルーのグラデーションを使う共通ボタン。
/// 「ランニング開始」CTA、ランニング計測画面の「スタート」ボタンなどで共用する。
class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final double? height;
  final Gradient gradient;
  final BorderRadius borderRadius;
  final List<BoxShadow>? boxShadow;
  final EdgeInsetsGeometry? padding;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.height,
    this.gradient = AppColors.routeSignGradient,
    this.borderRadius = const BorderRadius.all(Radius.circular(AppColors.radiusFull)),
    this.boxShadow,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onPressed,
        child: Ink(
          height: height,
          padding: padding,
          decoration: BoxDecoration(gradient: gradient, borderRadius: borderRadius, boxShadow: boxShadow),
          child: Center(child: child),
        ),
      ),
    );
  }
}
