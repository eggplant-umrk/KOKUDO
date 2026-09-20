import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 国道標識(おにぎり)の輪郭。上辺が水平で下に向かって尖る逆三角形、角は少し丸め。
///
/// [RouteSignBadge] のクリップ形状と、地図上のマーカー画像
/// (JapanMapPanel が Canvas で描く)の両方で使い、見た目を揃える。
Path routeSignPath(Size size) {
  final w = size.width;
  final h = size.height;
  final r = w * 0.12; // 角の丸みの半径(サイズに比例)

  return Path()
    ..moveTo(r, 0)
    ..lineTo(w - r, 0)
    ..quadraticBezierTo(w, 0, w, r)
    ..lineTo(w / 2 + r * 1.3, h - r * 1.8)
    ..quadraticBezierTo(w / 2, h, w / 2 - r * 1.3, h - r * 1.8)
    ..lineTo(0, r)
    ..quadraticBezierTo(0, 0, r, 0)
    ..close();
}

/// 実際の国道標識(通称「おにぎり」)をイメージした、上辺が水平で下に
/// 向かって尖る逆三角形のバッジ。角は少し丸めて硬すぎない印象にしている。
class RouteSignBadge extends StatelessWidget {
  final int? routeNumber;
  final double size;
  final double fontSize;
  final Color? color; // 単色で塗る場合(未挑戦・完走など)。gradientと排他。
  final Gradient? gradient; // グラデーションで塗る場合(挑戦中など)。未指定時はcolorを使う。
  final Color textColor;

  const RouteSignBadge({
    super.key,
    required this.routeNumber,
    this.size = 44,
    this.fontSize = 11,
    this.color,
    this.gradient,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedGradient = gradient ?? (color == null ? AppColors.routeSignGradient : null);
    return SizedBox(
      width: size,
      height: size,
      child: ClipPath(
        clipper: const _RouteSignClipper(),
        child: Container(
          decoration: BoxDecoration(color: color, gradient: resolvedGradient),
          alignment: const Alignment(0, -0.45), // 下が尖っている分、テキストは上寄りに
          child: Text(
            routeNumber != null ? '国道\n$routeNumber' : '？',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }
}

class _RouteSignClipper extends CustomClipper<Path> {
  const _RouteSignClipper();

  @override
  Path getClip(Size size) => routeSignPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
