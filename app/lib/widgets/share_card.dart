import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// RenderRepaintBoundary(画像化に使う)は material からは見えないので、
// rendering を直接読む。
import 'package:flutter/rendering.dart';

import '../theme/app_colors.dart';
import 'route_sign_badge.dart';

/// シェア画像の縦横。SNSごとに推奨が違うので2種類だけ用意する。
/// - [story] : Instagramストーリー(9:16)
/// - [square]: X・Facebook(1:1)
enum ShareCardFormat {
  story(1080, 1920),
  square(1080, 1080);

  const ShareCardFormat(this.width, this.height);

  final double width;
  final double height;

  Size get size => Size(width, height);
}

/// シェア画像に載せる中身。画面側で組み立てて渡す。
class ShareCardData {
  final int routeNumber;

  /// 「国道5号」。
  final String routeName;

  /// 「函館市 〜 札幌市」。
  final String segmentLabel;

  final double totalDistanceKm;

  /// 挑戦開始から完走までの日数(1日目から数える)。
  final int days;

  final DateTime completedAt;

  /// 道なりの線。1点は Offset(経度, 緯度)。
  final List<List<Offset>> routeLines;

  /// 路線が通る都道府県の輪郭(透かし用)。1点は Offset(経度, 緯度)。
  final List<List<Offset>> prefectureRings;

  /// 起点・終点。カタログの座標なので、GeoJSONの線の端から推測しなくてよい。
  final Offset? startPoint;
  final Offset? goalPoint;

  const ShareCardData({
    required this.routeNumber,
    required this.routeName,
    required this.segmentLabel,
    required this.totalDistanceKm,
    required this.days,
    required this.completedAt,
    this.routeLines = const [],
    this.prefectureRings = const [],
    this.startPoint,
    this.goalPoint,
  });
}

/// 完走をSNSに投稿するための画像。
///
/// 論理サイズは常に [ShareCardFormat] のピクセル数そのもの(1080×1920 など)。
/// 画面に出すときは呼び出し側で FittedBox などで縮め、RepaintBoundary で
/// `toImage(pixelRatio: 1.0)` すると、そのままの解像度のPNGになる。
class ShareCard extends StatelessWidget {
  final ShareCardFormat format;
  final ShareCardData data;

  /// キャラクターを出すかどうか。出すと地図の置き場所が右にずれる。
  final bool showCharacter;

  const ShareCard({
    super.key,
    required this.format,
    required this.data,
    this.showCharacter = false,
  });

  /// 道なりの線を収める枠。キャラクターの有無で変える。
  Rect get _mapRect => switch ((format, showCharacter)) {
        (ShareCardFormat.story, false) => const Rect.fromLTWH(230, 1018, 620, 470),
        (ShareCardFormat.story, true) => const Rect.fromLTWH(280, 1004, 520, 380),
        (ShareCardFormat.square, false) => const Rect.fromLTWH(330, 412, 420, 360),
        (ShareCardFormat.square, true) => const Rect.fromLTWH(602, 448, 370, 340),
      };

  /// キャラクターの絵が実際に見える範囲。
  Rect get _characterRect => format == ShareCardFormat.story
      ? const Rect.fromLTWH(52, 1018, 168, 430)
      : const Rect.fromLTWH(112, 456, 126, 322);

  bool get _isStory => format == ShareCardFormat.story;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: format.width,
      height: format.height,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(child: _Background()),
            // 都道府県の透かしと道なりの線。文字の下に敷くので Stack の先頭側。
            Positioned.fill(
              child: CustomPaint(
                painter: _MapLayerPainter(
                  routeLines: data.routeLines,
                  prefectureRings: data.prefectureRings,
                  startPoint: data.startPoint,
                  goalPoint: data.goalPoint,
                  mapRect: _mapRect,
                  lineWidth: _isStory ? 11 : 9,
                ),
              ),
            ),
            if (showCharacter) _buildCharacter(),
            ..._isStory ? _buildStoryContent() : _buildSquareContent(),
          ],
        ),
      ),
    );
  }

  /// キャラクターのアセットは 368×654 で、絵が入っているのは
  /// (96,140)-(257,552) の 161×412 だけ。周りの透明部分を数えずに
  /// [_characterRect] へ合わせたいので、逆算して画像全体を置く。
  Widget _buildCharacter() {
    const assetSize = Size(368, 654);
    const contentRect = Rect.fromLTWH(96, 140, 161, 412);
    final target = _characterRect;
    final scale = target.height / contentRect.height;
    return Positioned(
      left: target.left - contentRect.left * scale,
      top: target.top - contentRect.top * scale,
      width: assetSize.width * scale,
      height: assetSize.height * scale,
      child: Image.asset(
        'assets/character-run.webp',
        fit: BoxFit.fill,
        filterQuality: FilterQuality.medium,
        // 画像が読めなくてもシェア自体は成立させたいので、静かに省く。
        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
      ),
    );
  }

  // ---- ストーリー(1080×1920)。中央ぞろえ ----------------------------------

  List<Widget> _buildStoryContent() {
    return [
      const Positioned(left: 0, right: 0, top: 96, child: _Brand(fontSize: 29, letterSpacing: 6.96, dotSize: 11)),
      Positioned(left: 340, top: 212, child: _RouteSignPlate(routeNumber: data.routeNumber, size: 400)),
      Positioned(left: 0, right: 0, top: 663, child: _DoneLabel(fontSize: 74, letterSpacing: 16.28, center: true)),
      Positioned(
        left: 0,
        right: 0,
        top: 804,
        child: Text(
          data.routeName,
          textAlign: TextAlign.center,
          maxLines: 1,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 100,
            fontWeight: FontWeight.w900,
            height: 1.02,
          ),
        ),
      ),
      Positioned(
        left: 40,
        right: 40,
        top: 926,
        child: Text(
          data.segmentLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _skyText, fontSize: 36, fontWeight: FontWeight.w700, height: 1.4),
        ),
      ),
      Positioned(
        left: 84,
        top: 1502,
        width: 912,
        child: _StatsRow(
          data: data,
          verticalPadding: 42,
          valueFontSize: 62,
          unitFontSize: 30,
          keyFontSize: 25,
          gap: 14,
        ),
      ),
      const Positioned(
        left: 0,
        right: 0,
        top: 1740,
        child: Text(
          '走った距離で、日本の国道を走破する\nランニングアプリ KOKUDO',
          textAlign: TextAlign.center,
          style: TextStyle(color: _footText, fontSize: 27, fontWeight: FontWeight.w700, height: 1.55),
        ),
      ),
    ];
  }

  // ---- 正方形(1080×1080)。左ぞろえ ---------------------------------------

  List<Widget> _buildSquareContent() {
    return [
      const Positioned(left: 76, top: 70, child: _Brand(fontSize: 25, letterSpacing: 6, dotSize: 10)),
      Positioned(left: 76, top: 144, child: _RouteSignPlate(routeNumber: data.routeNumber, size: 280)),
      const Positioned(left: 396, top: 168, child: _DoneLabel(fontSize: 56, letterSpacing: 12.32, center: false)),
      Positioned(
        left: 396,
        right: 40,
        top: 265,
        child: Text(
          data.routeName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 80,
            fontWeight: FontWeight.w900,
            height: 1.02,
          ),
        ),
      ),
      Positioned(
        left: 396,
        right: 40,
        top: 358,
        child: Text(
          data.segmentLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: _skyText, fontSize: 29, fontWeight: FontWeight.w700, height: 1.4),
        ),
      ),
      Positioned(
        left: 76,
        top: 790,
        width: 928,
        child: _StatsRow(
          data: data,
          verticalPadding: 32,
          valueFontSize: 52,
          unitFontSize: 25,
          keyFontSize: 22,
          gap: 12,
        ),
      ),
      const Positioned(
        left: 76,
        top: 980,
        width: 928,
        child: Text(
          '走った距離で、日本の国道を走破する ランニングアプリ KOKUDO',
          textAlign: TextAlign.center,
          maxLines: 1,
          style: TextStyle(color: _footText, fontSize: 23, fontWeight: FontWeight.w700, height: 1.55),
        ),
      ),
    ];
  }
}

const Color _skyText = Color(0xFFA9D6F7);
const Color _footText = Color(0xFF8FBEE0);
const Color _routeLine = Color(0xFFB7E6FF);

/// 上が明るい濃紺のグラデーション。左上と右下にうっすら光を置く。
class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0, -1.05),
          radius: 1.25,
          colors: [Color(0xFF3A82C4), Color(0xFF22588E), Color(0xFF16395C)],
          stops: [0, 0.45, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned(left: -280, top: -280, child: _Glow(size: 860, color: const Color(0xFF57B7F5))),
          Positioned(right: -250, bottom: -180, child: _Glow(size: 720, color: const Color(0xFF2AA7E0))),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: 0.30), color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;
  final double dotSize;

  const _Brand({required this.fontSize, required this.letterSpacing, required this.dotSize});

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: dotSize,
      height: dotSize,
      decoration: const BoxDecoration(color: _skyText, shape: BoxShape.circle),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot,
        SizedBox(width: fontSize * 0.45),
        Text(
          'KOKUDO',
          style: TextStyle(
            color: _skyText,
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: letterSpacing,
          ),
        ),
        // 文字送りの分だけ右に空きができるので、その分を詰めてから点を置く。
        SizedBox(width: math.max(fontSize * 0.45 - letterSpacing, 0)),
        dot,
      ],
    );
  }
}

/// 白抜きの「完走」。囲みは付けず、オレンジの光だけを後ろに置く。
class _DoneLabel extends StatelessWidget {
  final double fontSize;
  final double letterSpacing;
  final bool center;

  const _DoneLabel({required this.fontSize, required this.letterSpacing, required this.center});

  @override
  Widget build(BuildContext context) {
    // letterSpacing は最後の文字の後ろにも入るので、中央ぞろえのときは
    // その半分だけ右にずれる。見た目の中心を合わせるために戻す。
    return Transform.translate(
      offset: Offset(center ? letterSpacing / 2 : 0, 0),
      child: Text(
        '完走',
        textAlign: center ? TextAlign.center : TextAlign.left,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: letterSpacing,
          height: 1.45,
          shadows: const [
            Shadow(color: Color(0x8CFFBE5A), blurRadius: 8),
            Shadow(color: Color(0xE6FF9619), blurRadius: 23),
            Shadow(color: Color(0xB3FF820A), blurRadius: 50),
            Shadow(color: Color(0x73FF6E00), blurRadius: 95),
          ],
        ),
      ),
    );
  }
}

/// 大きい国道標識。青く塗って白で縁取る。
class _RouteSignPlate extends StatelessWidget {
  final int routeNumber;
  final double size;

  const _RouteSignPlate({required this.routeNumber, required this.size});

  /// 白い縁が外へはみ出すぶん、標識そのものは箱より少し小さくする。
  static const double _signRatio = 0.918;
  static const double _inset = 0.041;

  @override
  Widget build(BuildContext context) {
    final signSize = size * _signRatio;
    final inset = size * _inset;
    final digits = routeNumber.toString().length;
    final numberRatio = switch (digits) {
      1 => 0.367,
      2 => 0.328,
      _ => 0.267,
    };
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _SignPlatePainter(signSize: signSize, inset: inset)),
          ),
          _baselineText('国道', inset, signSize * 0.300, signSize * 0.1556, signSize),
          _baselineText('$routeNumber', inset, signSize * 0.589, signSize * numberRatio, signSize),
          _baselineText('ROUTE', inset, signSize * 0.711, signSize * 0.0639, signSize,
              letterSpacing: signSize * 0.0056),
        ],
      ),
    );
  }

  /// ベースラインの位置で文字を置く。標識の中の3行は上下の間隔が決まって
  /// いるので、行の高さではなくベースラインで合わせないとずれる。
  Widget _baselineText(
    String text,
    double inset,
    double baseline,
    double fontSize,
    double signSize, {
    double letterSpacing = 0,
  }) {
    return Positioned(
      left: inset,
      top: inset,
      width: signSize,
      child: Transform.translate(
        offset: Offset(letterSpacing / 2, 0),
        child: Baseline(
          baseline: baseline,
          baselineType: TextBaseline.alphabetic,
          // Baseline は子に緩い制約を渡すので、Text は自分の幅まで縮んでしまい
          // textAlign が効かない。ここで標識の幅を与え直して中央ぞろえにする。
          child: SizedBox(
            width: signSize,
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                letterSpacing: letterSpacing,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignPlatePainter extends CustomPainter {
  final double signSize;
  final double inset;

  const _SignPlatePainter({required this.signSize, required this.inset});

  @override
  void paint(Canvas canvas, Size size) {
    final path = routeSignPath(Size(signSize, signSize)).shift(Offset(inset, inset));

    canvas.save();
    canvas.translate(0, signSize * 0.05);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x80000000)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, signSize * 0.11),
    );
    canvas.restore();

    canvas.drawPath(path, Paint()..color = AppColors.routeSignBlue);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = signSize * 0.061
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_SignPlatePainter oldDelegate) =>
      oldDelegate.signSize != signSize || oldDelegate.inset != inset;
}

/// 総距離・日数・完走日の3つ並び。
class _StatsRow extends StatelessWidget {
  final ShareCardData data;
  final double verticalPadding;
  final double valueFontSize;
  final double unitFontSize;
  final double keyFontSize;
  final double gap;

  const _StatsRow({
    required this.data,
    required this.verticalPadding,
    required this.valueFontSize,
    required this.unitFontSize,
    required this.keyFontSize,
    required this.gap,
  });

  @override
  Widget build(BuildContext context) {
    final date = data.completedAt;
    return Container(
      padding: EdgeInsets.symmetric(vertical: verticalPadding, horizontal: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        borderRadius: BorderRadius.circular(26),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _cell(data.totalDistanceKm.toStringAsFixed(1), 'km', '総距離')),
            _divider(),
            Expanded(child: _cell('${data.days}', '日', 'かかった日数')),
            _divider(),
            Expanded(child: _cell('${date.year}.${date.month}.${date.day}', null, '完走日')),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Container(width: 1, color: Colors.white.withValues(alpha: 0.20));

  Widget _cell(String value, String? unit, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              if (unit != null)
                Text(
                  unit,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: unitFontSize,
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(height: gap),
        Text(
          label,
          maxLines: 1,
          style: TextStyle(color: _skyText, fontSize: keyFontSize, fontWeight: FontWeight.w700, height: 1),
        ),
      ],
    );
  }
}

/// 都道府県の透かしと道なりの線を、同じ投影で描く。
///
/// 倍率は「道なりの線が [mapRect] にぴったり収まる大きさ」で決める。
/// 都道府県はその倍率のままなので、カードの外まではみ出して切れる。
/// これは意図した見せ方で、線を目いっぱい大きく見せるための割り切り。
class _MapLayerPainter extends CustomPainter {
  final List<List<Offset>> routeLines;
  final List<List<Offset>> prefectureRings;
  final Offset? startPoint;
  final Offset? goalPoint;
  final Rect mapRect;
  final double lineWidth;

  const _MapLayerPainter({
    required this.routeLines,
    required this.prefectureRings,
    required this.startPoint,
    required this.goalPoint,
    required this.mapRect,
    required this.lineWidth,
  });

  /// 透かしを描いてよい拡大率の上限(1度あたりのピクセル数)。
  ///
  /// 元データ(Natural Earth 1:10m)の海岸線は1km刻み程度しかないので、
  /// これより寄ると輪郭が地形ではなく直線の塊に見えてしまう。短い路線ほど
  /// 拡大率が上がるため、都市部の30km級の路線で問題になる。
  static const double _watermarkMaxScale = 1300;

  /// 透かしのために拡大率を抑えた結果、線が枠のこの割合より小さくなるなら、
  /// 透かしをあきらめて線を大きく見せる方を取る。0.5km級の路線では
  /// どのみち都道府県の形は読めないので、線だけの絵になる。
  static const double _watermarkMinLineFill = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    // 線が無い路線(GeoJSON未収録)は、県の形だけを枠に合わせて描く。
    final fitSource = routeLines.isNotEmpty ? routeLines : prefectureRings;
    if (fitSource.isEmpty) return;

    var minLng = double.infinity, maxLng = -double.infinity;
    var minLat = double.infinity, maxLat = -double.infinity;
    for (final line in fitSource) {
      for (final point in line) {
        if (point.dx < minLng) minLng = point.dx;
        if (point.dx > maxLng) maxLng = point.dx;
        if (point.dy < minLat) minLat = point.dy;
        if (point.dy > maxLat) maxLat = point.dy;
      }
    }
    if (!minLng.isFinite || !minLat.isFinite) return;

    // 経度1度は緯度が上がるほど短くなる。日本の範囲なら中央緯度の
    // cos を掛けるだけで十分(メルカトルまでは要らない)。
    final scaleX = math.cos((minLat + maxLat) / 2 * math.pi / 180);
    final spanX = math.max((maxLng - minLng) * scaleX, 1e-9);
    final spanY = math.max(maxLat - minLat, 1e-9);
    // 線の太さのぶんだけ内側に余白を取らないと、端が枠で切れて見える。
    final pad = lineWidth;
    final fitScale = math.min(
      math.max(mapRect.width - pad * 2, 1) / spanX,
      math.max(mapRect.height - pad * 2, 1) / spanY,
    );

    var scale = fitScale;
    var drawWatermark = prefectureRings.isNotEmpty;
    if (drawWatermark && routeLines.isNotEmpty && fitScale > _watermarkMaxScale) {
      if (_watermarkMaxScale / fitScale >= _watermarkMinLineFill) {
        scale = _watermarkMaxScale;
      } else {
        drawWatermark = false;
      }
    }

    final originX = mapRect.left + (mapRect.width - spanX * scale) / 2;
    final originY = mapRect.top + (mapRect.height - spanY * scale) / 2;

    Offset project(Offset point) => Offset(
          originX + (point.dx - minLng) * scaleX * scale,
          originY + (maxLat - point.dy) * scale,
        );

    if (drawWatermark) {
      final shape = Path();
      for (final ring in prefectureRings) {
        shape.addPolygon(ring.map(project).toList(growable: false), true);
      }
      canvas.drawPath(shape, Paint()..color = Colors.white.withValues(alpha: 0.10));
      canvas.drawPath(
        shape,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeJoin = StrokeJoin.round,
      );
    }

    if (routeLines.isNotEmpty) {
      final route = Path();
      for (final line in routeLines) {
        route.addPolygon(line.map(project).toList(growable: false), false);
      }
      // 透かしの上でも沈まないよう、太くて薄い同色を下に敷く。
      canvas.drawPath(
        route,
        Paint()
          ..color = _routeLine.withValues(alpha: 0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth * 2.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        route,
        Paint()
          ..color = _routeLine
          ..style = PaintingStyle.stroke
          ..strokeWidth = lineWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      final start = startPoint;
      final goal = goalPoint;
      if (start != null) {
        canvas.drawCircle(project(start), lineWidth * 1.5, Paint()..color = Colors.white);
      }
      if (goal != null) {
        canvas.drawCircle(project(goal), lineWidth * 1.8, Paint()..color = AppColors.accentGold);
      }
    }
  }

  @override
  bool shouldRepaint(_MapLayerPainter oldDelegate) =>
      !identical(oldDelegate.routeLines, routeLines) ||
      !identical(oldDelegate.prefectureRings, prefectureRings) ||
      oldDelegate.startPoint != startPoint ||
      oldDelegate.goalPoint != goalPoint ||
      oldDelegate.mapRect != mapRect ||
      oldDelegate.lineWidth != lineWidth;
}

/// [ShareCard] を画像にする。[boundaryKey] は ShareCard を包んだ
/// RepaintBoundary に付けたキー。
Future<Uint8List?> captureShareCard(GlobalKey boundaryKey) async {
  final object = boundaryKey.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) return null;
  // 論理サイズ = 出力ピクセル数なので、倍率は1でよい。
  final image = await object.toImage(pixelRatio: 1);
  try {
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes?.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}
