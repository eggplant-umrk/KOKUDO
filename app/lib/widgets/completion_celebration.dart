import 'dart:math';

import 'package:flutter/material.dart';

import '../models/national_route.dart';
import '../theme/app_colors.dart';
import 'gradient_button.dart';
import 'route_sign_badge.dart';

/// 完走(路線を100%まで走り切った)タイミングで表示するお祝い演出。
/// 新規パッケージを追加せず(maplibre_glでGradle互換性トラブルを踏んだ教訓から)、
/// CustomPainterで紙吹雪を自前描画している。
Future<void> showCompletionCelebration(BuildContext context, NationalRoute route) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: '完走',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (context, animation, secondaryAnimation) {
      return _CompletionCelebrationDialog(route: route);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: curved, child: child),
      );
    },
  );
}

class _CompletionCelebrationDialog extends StatefulWidget {
  final NationalRoute route;
  const _CompletionCelebrationDialog({required this.route});

  @override
  State<_CompletionCelebrationDialog> createState() => _CompletionCelebrationDialogState();
}

class _CompletionCelebrationDialogState extends State<_CompletionCelebrationDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _confettiController;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
    final random = Random();
    _pieces = List.generate(46, (_) => _ConfettiPiece.random(random));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConfettiPainter(pieces: _pieces, progress: _confettiController.value),
                  );
                },
              ),
            ),
          ),
          _CelebrationCard(route: route),
        ],
      ),
    );
  }
}

class _CelebrationCard extends StatelessWidget {
  final NationalRoute route;
  const _CelebrationCard({required this.route});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RouteSignBadge(routeNumber: route.routeNumber, size: 68, fontSize: 16),
            const SizedBox(height: 16),
            const Text(
              '🎉 完走おめでとう！',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              '国道${route.routeNumber}号 ${route.name}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              '全${route.totalDistanceKm.toStringAsFixed(1)}kmを走破しました',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: GradientButton(
                height: 48,
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  '閉じる',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 紙吹雪1片分のパラメータ。0〜1の進捗(progress)を受け取って
/// 落下位置・回転・揺れをCustomPainter側で計算する。
class _ConfettiPiece {
  final double startX; // 0〜1 (画面幅比)
  final double delay; // 0〜1 (アニメーション開始までの遅延比)
  final double fallSpeed; // 落下の速さの個体差
  final double swayAmount; // 左右の揺れ幅
  final double swaySpeed;
  final double rotationSpeed;
  final double size;
  final Color color;

  _ConfettiPiece({
    required this.startX,
    required this.delay,
    required this.fallSpeed,
    required this.swayAmount,
    required this.swaySpeed,
    required this.rotationSpeed,
    required this.size,
    required this.color,
  });

  static const _colors = [
    AppColors.accentGold,
    AppColors.accentGreen,
    AppColors.accentBlue,
    AppColors.routeSignBlueLight,
    Color(0xFFFF7A7A),
  ];

  factory _ConfettiPiece.random(Random random) {
    return _ConfettiPiece(
      startX: random.nextDouble(),
      delay: random.nextDouble() * 0.25,
      fallSpeed: 0.7 + random.nextDouble() * 0.6,
      swayAmount: 8 + random.nextDouble() * 18,
      swaySpeed: 2 + random.nextDouble() * 3,
      rotationSpeed: (random.nextBool() ? 1 : -1) * (2 + random.nextDouble() * 4),
      size: 6 + random.nextDouble() * 6,
      color: _colors[random.nextInt(_colors.length)],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiPiece> pieces;
  final double progress;

  _ConfettiPainter({required this.pieces, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final piece in pieces) {
      final localProgress = ((progress - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (localProgress <= 0) continue;

      final y = -20 + localProgress * (size.height + 40) * piece.fallSpeed;
      if (y > size.height + 20) continue;

      final sway = sin(localProgress * piece.swaySpeed * 2 * pi) * piece.swayAmount;
      final x = piece.startX * size.width + sway;
      final rotation = localProgress * piece.rotationSpeed * pi;
      final opacity = localProgress > 0.85 ? (1 - localProgress) / 0.15 : 1.0;

      final paint = Paint()..color = piece.color.withValues(alpha: opacity.clamp(0.0, 1.0));

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(rotation);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * 0.5),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}
