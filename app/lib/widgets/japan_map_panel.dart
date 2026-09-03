import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';

/// 走破・地図コレクション画面用の簡易日本地図。
/// 8地方を丸みのあるブロブで表現し、各国道を地方の位置にピン表示する。
/// ブロブをタップすると、その地方でルート一覧を絞り込める（地方タブの代わり）。
class _RegionBlob {
  final RegionKey key;
  final String label;
  final double cx;
  final double cy;
  final double rx;
  final double ry;
  final int seed;

  const _RegionBlob(this.key, this.label, this.cx, this.cy, this.rx, this.ry, this.seed);
}

const List<_RegionBlob> _blobs = [
  _RegionBlob(RegionKey.hokkaido, '北海道', 176, 28, 26, 21, 3),
  _RegionBlob(RegionKey.tohoku, '東北', 151, 76, 21, 27, 11),
  _RegionBlob(RegionKey.kanto, '関東', 148, 126, 19, 17, 7),
  _RegionBlob(RegionKey.chubu, '中部', 109, 116, 23, 21, 19),
  _RegionBlob(RegionKey.kinki, '近畿', 81, 153, 17, 15, 5),
  _RegionBlob(RegionKey.chugoku, '中国', 49, 165, 19, 12, 23),
  _RegionBlob(RegionKey.shikoku, '四国', 67, 186, 14, 10, 13),
  _RegionBlob(RegionKey.kyushuOkinawa, '九州・沖縄', 33, 205, 19, 17, 29),
];

const Map<String, Offset> _markerOffset = {
  '174': Offset(11, 9),
  '130': Offset(-10, -9),
  '134': Offset(10, -3),
  '1': Offset(-2, 11),
  '292': Offset(-5, -10),
  '4': Offset(2, -7),
};

const Map<RouteStatus, Color> _statusFill = {
  RouteStatus.notStarted: AppColors.routeInactive,
  RouteStatus.inProgress: AppColors.routeSignBlue,
  RouteStatus.completed: AppColors.accentGold,
};

// 元のSVG viewBox="-14 -10 228 256" と同じ仮想座標系を使う。
const double _vbX = -14;
const double _vbY = -10;
const double _vbW = 228;
const double _vbH = 256;

/// 地方の位置を、単純な楕円ではなく少し有機的な「島」っぽい輪郭で描くための
/// ブロブ形状パス生成。seed値ごとに決まった形になる（毎回同じ形で安定表示）。
Path _blobPath(double cx, double cy, double rx, double ry, int seed) {
  const pointCount = 10;
  final angleStep = (2 * math.pi) / pointCount;
  int s = seed;
  double rand() {
    s = (s * 9301 + 49297) % 233280;
    return s / 233280;
  }

  final pts = <Offset>[];
  for (var i = 0; i < pointCount; i++) {
    final angle = i * angleStep;
    final variance = 0.86 + rand() * 0.28; // 0.86〜1.14
    pts.add(Offset(cx + math.cos(angle) * rx * variance, cy + math.sin(angle) * ry * variance));
  }

  Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

  final path = Path();
  final start = mid(pts.last, pts.first);
  path.moveTo(start.dx, start.dy);
  for (var i = 0; i < pts.length; i++) {
    final next = pts[(i + 1) % pts.length];
    final m = mid(pts[i], next);
    path.quadraticBezierTo(pts[i].dx, pts[i].dy, m.dx, m.dy);
  }
  path.close();
  return path;
}

/// Googleマップ風のしずく型ピン。先端（tipX, tipY）が実際の地点を指す。
Path _pinPath(double tipX, double tipY, double r) {
  final topY = tipY - r * 2.6;
  final path = Path();
  path.moveTo(tipX, tipY);
  path.cubicTo(tipX - r, tipY - r * 1.3, tipX - r, tipY - r * 2.2, tipX, topY);
  path.cubicTo(tipX + r, tipY - r * 2.2, tipX + r, tipY - r * 1.3, tipX, tipY);
  path.close();
  return path;
}

class JapanMapPanel extends StatefulWidget {
  final List<NationalRoute> routes;
  final RegionKey? activeRegion; // nullは「すべて」
  final ValueChanged<RegionKey?> onSelectRegion;
  final RouteStatus Function(String routeId) statusOf;

  const JapanMapPanel({
    super.key,
    required this.routes,
    required this.activeRegion,
    required this.onSelectRegion,
    required this.statusOf,
  });

  @override
  State<JapanMapPanel> createState() => _JapanMapPanelState();
}

class _JapanMapPanelState extends State<JapanMapPanel> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details, Size size) {
    final scaleX = size.width / _vbW;
    final scaleY = size.height / _vbH;
    final p = Offset(
      details.localPosition.dx / scaleX + _vbX,
      details.localPosition.dy / scaleY + _vbY,
    );
    for (final b in _blobs) {
      final path = _blobPath(b.cx, b.cy, b.rx, b.ry, b.seed);
      if (path.contains(p)) {
        widget.onSelectRegion(widget.activeRegion == b.key ? null : b.key);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 178);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details, size),
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  size: size,
                  painter: _JapanMapPainter(
                    routes: widget.routes,
                    activeRegion: widget.activeRegion,
                    statusOf: widget.statusOf,
                    pulseT: _pulseController.value,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class _JapanMapPainter extends CustomPainter {
  final List<NationalRoute> routes;
  final RegionKey? activeRegion;
  final RouteStatus Function(String routeId) statusOf;
  final double pulseT;

  _JapanMapPainter({
    required this.routes,
    required this.activeRegion,
    required this.statusOf,
    required this.pulseT,
  });

  _RegionBlob? _blobFor(RegionKey key) {
    for (final b in _blobs) {
      if (b.key == key) return b;
    }
    return null;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _vbW;
    final scaleY = size.height / _vbH;
    canvas.save();
    canvas.scale(scaleX, scaleY);
    canvas.translate(-_vbX, -_vbY);

    // 地方ブロブ（陸地）
    for (final b in _blobs) {
      final selected = activeRegion == b.key;
      final path = _blobPath(b.cx, b.cy, b.rx, b.ry, b.seed);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.fill
          ..color = selected ? AppColors.routeSignBlue.withValues(alpha: 0.22) : AppColors.mapLand,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 2 : 1.4
          ..color = selected ? AppColors.routeSignBlue : AppColors.mapLandBorder,
      );

      final label = b.label == '九州・沖縄' ? '九州' : b.label;
      final fillColor = selected ? AppColors.routeSignBlue : AppColors.mapLabel;

      // クリーム色のハロー（縁取り）を先に描いてから本体を重ねる（Googleマップ風の可読性向上）
      final haloPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeJoin = StrokeJoin.round
              ..color = AppColors.mapLand,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      haloPainter.paint(canvas, Offset(b.cx - haloPainter.width / 2, b.cy + 3.5 - haloPainter.height / 2));

      final labelPainter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fillColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelPainter.paint(canvas, Offset(b.cx - labelPainter.width / 2, b.cy + 3.5 - labelPainter.height / 2));
    }

    // ルートのピンマーカー
    for (final r in routes) {
      final blob = _blobFor(r.region);
      if (blob == null) continue;
      final offset = _markerOffset[r.routeId] ?? Offset.zero;
      final status = statusOf(r.routeId);
      final cx = blob.cx + offset.dx;
      final cy = blob.cy + offset.dy;
      final pinR = status == RouteStatus.inProgress ? 4.6 : 3.9;

      if (status == RouteStatus.inProgress) {
        final pulseOpacity = (0.4 * (1 - pulseT)).clamp(0.0, 1.0).toDouble();
        final pulseRadius = 5 + (5 * 1.3) * pulseT; // scale(1) → scale(2.3) 相当
        canvas.drawCircle(
          Offset(cx, cy),
          pulseRadius,
          Paint()..color = AppColors.routeSignBlue.withValues(alpha: pulseOpacity),
        );
      }

      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy + 1), width: pinR * 1.4, height: pinR * 0.48),
        Paint()..color = const Color(0x47141E1E),
      );

      final pinPath = _pinPath(cx, cy, pinR);
      canvas.drawPath(pinPath, Paint()..color = _statusFill[status]!);
      canvas.drawPath(
        pinPath,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white,
      );

      canvas.drawCircle(Offset(cx, cy - pinR * 1.55), pinR * 0.4, Paint()..color = Colors.white);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _JapanMapPainter oldDelegate) {
    return oldDelegate.activeRegion != activeRegion ||
        oldDelegate.pulseT != pulseT ||
        oldDelegate.routes != routes;
  }
}
