import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

/// 国道標識(おにぎり)の輪郭。[RouteSignBadge] と [RouteSignMark] で同じ形を
/// 使うために切り出している。
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

class _RouteSignClipper extends CustomClipper<Path> {
  const _RouteSignClipper();

  @override
  Path getClip(Size size) => routeSignPath(size);

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

/// 国道標識の形をした小さな印。中に日付などを置ける。
/// [filled] が false のときは輪郭線だけを描く。
/// カレンダーで「その日走った」ことを示すのに使う。
class RouteSignMark extends StatelessWidget {
  final double size;
  final Color color;
  final bool filled;
  final double strokeWidth;
  final Widget? child;

  const RouteSignMark({
    super.key,
    required this.size,
    required this.color,
    this.filled = false,
    this.strokeWidth = 1.4,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RouteSignMarkPainter(color: color, filled: filled, strokeWidth: strokeWidth),
      child: SizedBox(
        width: size,
        height: size,
        // 下が尖っているぶん、中身は上寄りに置かないと輪郭から はみ出す。
        child: Align(alignment: const Alignment(0, -0.45), child: child),
      ),
    );
  }
}

class _RouteSignMarkPainter extends CustomPainter {
  final Color color;
  final bool filled;
  final double strokeWidth;

  const _RouteSignMarkPainter({
    required this.color,
    required this.filled,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 線は中心から外へ半分はみ出すので、輪郭のときはその分だけ内側に縮める。
    final inset = filled ? 0.0 : strokeWidth / 2;
    final path = routeSignPath(Size(size.width - inset * 2, size.height - inset * 2))
        .shift(Offset(inset, inset));
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = filled ? PaintingStyle.fill : PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_RouteSignMarkPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.filled != filled ||
      oldDelegate.strokeWidth != strokeWidth;
}
