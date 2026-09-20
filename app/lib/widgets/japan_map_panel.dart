import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import 'route_sign_badge.dart' show routeSignPath;

/// 走破・地図コレクション画面用の実地図パネル（MapLibre GL）。
///
/// 各国道の起点・終点にステータス別の色分けマーカー（未走破=グレー、
/// 挑戦中=ネオンブルー、完走=ゴールド）を表示する。起点は路線番号入りの
/// 国道標識（おにぎり）で、尖った下端が起点の位置を指す。終点（ゴール）は
/// 白地に色付きの太い縁取りの円で区別する。マーカーをタップするとその路線が
/// 属する地方でフィルターできる（もう一度タップで解除）。
///
/// 地図は北固定（回転・チルト不可）。[onRequestFullscreen] を渡すと右上に
/// 全画面ボタンが出て、マーカー以外の場所をタップしたときにも呼ばれる。
/// [height] を null にすると親（Expanded など）のサイズいっぱいに広がる。
/// さらに、各路線の実際の道なり（`NationalRoute.geojsonPath` が指す
/// GeoJSON）をステータス色の線として地図に描画する。GeoJSONアセットが
/// まだ用意されていない路線は、その路線の線だけを静かに省略する
/// （起点・終点マーカーの表示は妨げない）。
///
/// また、路線が1本もない地方でもフィルターを選べるよう、8地方それぞれの
/// 代表地点に常時タップ可能な地方マーカー（ラベル付き）を別途表示する。
class JapanMapPanel extends StatefulWidget {
  final List<NationalRoute> routes;
  final RegionKey? activeRegion; // nullは「すべて」
  final ValueChanged<RegionKey?> onSelectRegion;
  final RouteStatus Function(String routeId) statusOf;
  final double? height;
  final VoidCallback? onRequestFullscreen;

  const JapanMapPanel({
    super.key,
    required this.routes,
    required this.activeRegion,
    required this.onSelectRegion,
    required this.statusOf,
    this.height = 220,
    this.onRequestFullscreen,
  });

  @override
  State<JapanMapPanel> createState() => JapanMapPanelState();
}

/// 地図の背景スタイル。
///
/// 以前は MapLibre のデモ用タイルサーバー(demotiles.maplibre.org)を参照していたが、
/// デモ用のため粗い世界地図しか持たず、継続提供の保証もない。KOKUDOは日本国内の
/// 国道しか扱わないため、国土地理院が公開する「最適化ベクトルタイル」に切り替える。
///
/// 画像タイル(淡色地図など)ではなくベクトルタイルを使うのは、描く要素と色を
/// こちらで決められるため。淡色地図は寄ると高速道路番号・河川・地名が密に描かれて
/// 路線やマーカーが埋もれ、彩度を落として誤魔化すと今度はアプリの雰囲気に合わない
/// 灰色の地図になってしまう。ベクトルタイルなら海・陸・海岸線・県境・主要道路だけを
/// アプリ共通のマップ配色(AppColors.mapWater* / mapLand*)で平坦に描け、
/// 「さわやかでポップ」なUIに馴染むイラスト調の地図になる。
///
/// ベクトルタイルはズームレベル4〜16でしか配信されていないため、日本全体を俯瞰する
/// 引きの表示(ズーム4未満)ではタイルが存在しない。そこで背景を2層にする。
///   1. 陸地の輪郭(assets/map/japan_land.geojson)を塗った層。アプリに同梱しており
///      ズームに関係なく常に描かれる。[_addLandSilhouette] でスタイル読み込み後に追加。
///   2. ベクトルタイルの層(ズーム4以上)。
/// どちらの層も同じ配色なので、切り替わりはほとんど見えない。
///
/// 注意: このベクトルタイルはズーム帯で海の表現が変わる(地理院公式スタイル準拠)。
///   - ズーム4〜8: 背景=海の色、陸は AdmArea(行政区域)の面で塗る。海のポリゴンは無い。
///   - ズーム8以上: 背景=陸の色、海・湖・川は WA(水域)の面で塗る。
/// そのため背景色をズーム8で海→陸に切り替え、AdmArea と WA の両方の面を描いている。
/// どちらか片方だけにすると、特定のズーム帯で海まで陸の色になってしまう。
///
/// 国土地理院最適化ベクトルタイルは試験公開(2022年9月〜)だが無償で、出典の記載が
/// 必要なため地図右下に常時表示している。
/// 仕様: https://github.com/gsi-cyberjapan/optimal_bvmap
const String _mapStyle = '''
{
  "version": 8,
  "glyphs": "$_glyphsUrl",
  "sources": {
    "gsi-vector": {
      "type": "vector",
      "tiles": ["https://cyberjapandata.gsi.go.jp/xyz/optimal_bvmap-v1/{z}/{x}/{y}.pbf"],
      "minzoom": 4,
      "maxzoom": 16,
      "attribution": "国土地理院ベクトルタイル"
    }
  },
  "layers": [
    {
      "id": "background",
      "type": "background",
      "paint": {
        "background-color": ["step", ["zoom"], "$_seaHexColor", 8, "$_landHexColor"]
      }
    },
    {
      "id": "$_landTileLayerId",
      "type": "fill",
      "source": "gsi-vector",
      "source-layer": "AdmArea",
      "paint": { "fill-color": "$_landHexColor" }
    },
    {
      "id": "water",
      "type": "fill",
      "source": "gsi-vector",
      "source-layer": "WA",
      "paint": { "fill-color": "$_seaHexColor" }
    },
    {
      "id": "coastline",
      "type": "line",
      "source": "gsi-vector",
      "source-layer": "Cstline",
      "paint": {
        "line-color": "$_coastHexColor",
        "line-width": ["interpolate", ["linear"], ["zoom"], 4, 0.6, 10, 1.2, 16, 1.6]
      }
    },
    {
      "id": "water-edge",
      "type": "line",
      "source": "gsi-vector",
      "source-layer": "WL",
      "minzoom": 9,
      "paint": { "line-color": "$_coastHexColor", "line-width": 0.6 }
    },
    {
      "id": "river",
      "type": "line",
      "source": "gsi-vector",
      "source-layer": "RvrCL",
      "minzoom": 9,
      "paint": {
        "line-color": "$_riverHexColor",
        "line-width": ["interpolate", ["linear"], ["zoom"], 9, 0.6, 14, 1.4]
      }
    },
    {
      "id": "pref-boundary",
      "type": "line",
      "source": "gsi-vector",
      "source-layer": "AdmBdry",
      "minzoom": 5,
      "paint": {
        "line-color": "$_boundaryHexColor",
        "line-width": 0.8,
        "line-dasharray": [3, 2]
      }
    },
    {
      "id": "road",
      "type": "line",
      "source": "gsi-vector",
      "source-layer": "RdCL",
      "minzoom": 8,
      "filter": ["!=", ["get", "vt_motorway"], 1],
      "layout": { "line-cap": "round", "line-join": "round" },
      "paint": {
        "line-color": "$_roadHexColor",
        "line-width": ["interpolate", ["linear"], ["zoom"], 8, 0.5, 12, 1.0, 16, 2.4]
      }
    },
    {
      "id": "motorway",
      "type": "line",
      "source": "gsi-vector",
      "source-layer": "RdCL",
      "minzoom": 7,
      "filter": ["==", ["get", "vt_motorway"], 1],
      "layout": { "line-cap": "round", "line-join": "round" },
      "paint": {
        "line-color": "$_motorwayHexColor",
        "line-width": ["interpolate", ["linear"], ["zoom"], 7, 0.8, 12, 1.6, 16, 3.0]
      }
    },
    {
      "id": "railway",
      "type": "line",
      "source": "gsi-vector",
      "source-layer": "RailCL",
      "minzoom": 10,
      "paint": {
        "line-color": "$_railHexColor",
        "line-width": 1.0,
        "line-dasharray": [4, 3]
      }
    },
    {
      "id": "place-label",
      "type": "symbol",
      "source": "gsi-vector",
      "source-layer": "Anno",
      "minzoom": $_signMinZoom,
      "filter": ["in", ["get", "vt_code"], ["literal", [110, 130, 140]]],
      "layout": {
        "text-field": ["get", "vt_text"],
        "text-font": ["$_fontName"],
        "text-size": ["interpolate", ["linear"], ["zoom"], 7, 10, 12, 12],
        "text-padding": 6
      },
      "paint": {
        "text-color": "$_labelHexColor",
        "text-halo-color": "#FFFFFF",
        "text-halo-width": 1.2
      }
    }
  ]
}
''';

/// 文字(地名ラベル・地方ラベル)のフォント。国土地理院が地理院地図Vector用に
/// 配布しているグリフサーバーと、そこにある Noto Sans CJK JP を使う。
/// スタイルに glyphs が無い、または存在しないフォント名を指定すると、
/// シンボル(文字・画像マーカー)の層が丸ごと描かれないことがあるため、
/// スタイル側のラベルと addSymbol 側の [SymbolOptions.fontNames] の両方で
/// 必ずこのフォント名を指定する。
const String _glyphsUrl = 'https://maps.gsi.go.jp/xyz/noto-jp/{fontstack}/{range}.pbf';
const String _fontName = 'NotoSansCJKjp-Regular';

/// 地図の配色。
/// アプリ上部のグラデーション(AppColors.bgAppTop)の明るい空色に合わせ、
/// 「明るいクリーム色の陸に鮮やかな空色の海」を基調にしたさわやかな配色にする。
/// 陸は AppColors.mapLand(#F4EFE2)だと灰色が混ざってくすんで見えるため、
/// 灰色を混ぜない黄み寄りの白にしている。道路・県境・鉄道は陸と同系の暖色で
/// 一段ずつ濃くしただけにし、路線やマーカーより目立たないようにする。
/// (MapLibre のスタイルJSONは文字列で渡すため16進文字列で持つ。)
const String _seaHexColor = '#B9E6FF'; // 海: bgAppTop(#CDF1FF)より一段濃い空色
const String _landHexColor = '#FFF8E3'; // 陸: 明るいクリーム色(灰色を混ぜない、黄み寄りの白)
const String _coastHexColor = '#7CCBF0'; // 海岸線: accentBlue系の明るい水色
const String _boundaryHexColor = '#E6D9B6'; // 県境(破線): クリームより一段濃い暖色
const String _riverHexColor = '#A4DCF7'; // 川
const String _roadHexColor = '#EFE5C9'; // 一般道: 陸より一段濃いだけの薄い暖色
const String _motorwayHexColor = '#E2D3AC'; // 高速道路: 一般道より少し濃く
const String _railHexColor = '#DDD4BE'; // 鉄道(破線)
const String _labelHexColor = '#5C6F7D'; // 地名: AppColors.textSecondary

/// 陸地の輪郭を描く層のID。タイル由来の最初の層(陸の面)より下に差し込むために使う。
const String _landSourceId = 'japan-land';
const String _landFillLayerId = 'japan-land-fill';
const String _landLineLayerId = 'japan-land-line';
const String _landTileLayerId = 'land';

/// 同梱シルエットの不透明度。タイルの陸(AdmArea)が現れるズーム4から5にかけて
/// 消していく。同梱データは粗い(Natural Earth 1:50m)ため、寄った状態で残すと
/// タイルの精密な海岸線と輪郭がずれて二重に見えてしまう。
const List<Object> _silhouetteOpacity = ['interpolate', ['linear'], ['zoom'], 4, 1, 5, 0];

/// ネオンブルー（挑戦中）はブランドの標識ブルーより彩度を上げた色を使う。
/// [_statusHexColor] はスタイル/アノテーション用の文字列、[_statusColor] は
/// Canvas で標識画像を描くとき用。値は同じに保つこと。
const Map<RouteStatus, String> _statusHexColor = {
  RouteStatus.notStarted: '#CFDBE2',
  RouteStatus.inProgress: '#2FA9FF',
  RouteStatus.completed: '#FFB238',
};
const Map<RouteStatus, Color> _statusColor = {
  RouteStatus.notStarted: Color(0xFFCFDBE2),
  RouteStatus.inProgress: Color(0xFF2FA9FF),
  RouteStatus.completed: Color(0xFFFFB238),
};

/// 8地方それぞれの代表地点（おおよその中心座標）。
/// 路線マーカーが無い地方でも、ここに常時タップ可能なマーカーを表示することで
/// 地方フィルターを選べるようにする。
const Map<RegionKey, LatLng> _regionCenters = {
  RegionKey.hokkaido: LatLng(43.5, 142.6),
  RegionKey.tohoku: LatLng(39.0, 140.9),
  RegionKey.kanto: LatLng(36.1, 139.8),
  RegionKey.chubu: LatLng(36.5, 137.9),
  RegionKey.kinki: LatLng(34.8, 135.6),
  RegionKey.chugoku: LatLng(34.5, 132.8),
  RegionKey.shikoku: LatLng(33.8, 133.5),
  RegionKey.kyushuOkinawa: LatLng(32.6, 130.7),
};

const Map<RegionKey, String> _regionShortLabel = {
  RegionKey.hokkaido: '北海道',
  RegionKey.tohoku: '東北',
  RegionKey.kanto: '関東',
  RegionKey.chubu: '中部',
  RegionKey.kinki: '近畿',
  RegionKey.chugoku: '中国',
  RegionKey.shikoku: '四国',
  RegionKey.kyushuOkinawa: '九州',
};

/// 国道標識マーカーの表示サイズ(論理px = dp)。
const double _signSize = 40;

/// 起点マーカーの国道標識を描き始めるズームレベル。地名ラベル(スタイルの
/// place-label 層の minzoom)もこの値に揃えてあり、地名が読める程度に寄ると
/// 同時に標識も立つ。これより引いた表示では起点の小さな色付きの丸だけが見える。
/// (引きで標識まで出すと、東京の1号・4号・134号などが重なって読めなくなる。)
const double _signMinZoom = 7.0;

/// 地方ラベル・国道標識のソース/レイヤーID。
///
/// これらは maplibre_gl のアノテーション(addSymbol)ではなく、GeoJSONソース＋
/// シンボルレイヤーとして自前で描く。アノテーションのシンボルは文字のフォントが
/// プラグイン側で "Noto Sans Regular" に固定されており、グリフサーバーに無いため
/// 404 になって、文字の無い標識まで同じ層ごと描かれなくなる(実機で確認済み)。
/// レイヤーなら [_fontName] を確実に指定でき、minzoom による出し分けも
/// MapLibre に任せられる。
const String _regionLabelSourceId = 'region-labels';
const String _regionLabelLayerId = 'region-labels';
const String _routeSignSourceId = 'route-signs';
const String _routeSignLayerId = 'route-signs';

class JapanMapPanelState extends State<JapanMapPanel> {
  MapLibreMapController? _controller;
  final Map<String, Circle> _startCircleByRouteId = {};
  final Map<String, Circle> _goalCircleByRouteId = {};
  final Map<RegionKey, Circle> _circleByRegion = {};
  final Set<String> _lineLayerIds = {};
  final Set<String> _lineSourceIds = {};

  /// [_syncMarkers] の多重実行防止。実行中に再要求が来たら終了後にもう一度走らせる。
  bool _syncing = false;
  bool _syncRequested = false;

  /// スタイルに登録済みの標識画像の名前と、地方ラベル/標識レイヤーの作成済みフラグ。
  /// どちらもスタイルを読み直すと消えるので、[_onStyleLoaded] でリセットする。
  final Set<String> _registeredSignImages = {};
  bool _overlayLayersReady = false;

  static const CameraPosition _initialCamera = CameraPosition(
    target: LatLng(36.5, 138.2),
    zoom: 3.9,
  );

  @override
  void didUpdateWidget(covariant JapanMapPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller != null &&
        (oldWidget.routes != widget.routes ||
            oldWidget.activeRegion != widget.activeRegion)) {
      _syncMarkers();
    }
  }

  @override
  void dispose() {
    final controller = _controller;
    controller?.onCircleTapped.remove(_handleCircleTapped);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onCircleTapped.add(_handleCircleTapped);
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _registeredSignImages.clear();
    _overlayLayersReady = false;
    await _addLandSilhouette(controller);
    await _ensureOverlayLayers(controller);
    await _syncMarkers();
  }

  /// 地方ラベルと国道標識のソース/レイヤーを(空の状態で)作る。
  /// 中身は [_syncMarkersNow] が setGeoJsonSource で入れ替える。
  Future<void> _ensureOverlayLayers(MapLibreMapController controller) async {
    if (_overlayLayersReady) return;
    try {
      await controller.addGeoJsonSource(_regionLabelSourceId, _emptyFeatureCollection());
      await controller.addSymbolLayer(
        _regionLabelSourceId,
        _regionLabelLayerId,
        const SymbolLayerProperties(
          textField: [Expressions.get, 'label'],
          textFont: [_fontName],
          textSize: 10,
          textColor: '#3C4043',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.2,
          // 地方ラベルは常に見せる(背景の地名と重なっても消さない)。
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        enableInteraction: false,
      );

      await controller.addGeoJsonSource(_routeSignSourceId, _emptyFeatureCollection());
      await controller.addSymbolLayer(
        _routeSignSourceId,
        _routeSignLayerId,
        const SymbolLayerProperties(
          iconImage: [Expressions.get, 'icon'],
          iconSize: [Expressions.get, 'size'],
          iconAnchor: 'bottom',
          iconOpacity: 0.97,
          // 標識同士が重なるときは MapLibre に間引かせる(寄れば両方出る)。
          iconAllowOverlap: false,
        ),
        minzoom: _signMinZoom,
        enableInteraction: false,
      );
      _overlayLayersReady = true;
    } catch (_) {
      // 作れなかった場合は未作成のままにする。地方ラベル・標識は出ないが、
      // 丸マーカーと路線の線は描けるので続行する(線の belowLayerId も付けない)。
    }
  }

  static Map<String, dynamic> _emptyFeatureCollection() =>
      {'type': 'FeatureCollection', 'features': <Map<String, dynamic>>[]};

  static Map<String, dynamic> _pointFeature(LatLng at, Map<String, dynamic> properties) => {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [at.longitude, at.latitude],
        },
        'properties': properties,
      };

  /// 路線番号入りの国道標識をその場で描画してPNG化し、MapLibre のスタイルに
  /// 画像として登録する。同じ番号・同じ色の画像は一度だけ登録する。
  ///
  /// 形は [RouteSignBadge] と同じ [routeSignPath] を使い、リストのバッジと
  /// 見た目を揃える。文字は「国道」と番号の2行。
  ///
  /// 解像度の扱い: 画像は端末の画面密度([devicePixelRatio])倍の物理pxで描く。
  /// Android 側のプラグインは渡されたビットマップに端末密度をそのまま
  /// pixelRatio として付けるため、iconSize=1 でちょうど [_signSize] dp の
  /// 鮮明な標識になる。iOS 側は密度を付けずに登録する(scale=1)ため、
  /// 表示時に 1/devicePixelRatio に縮める必要がある([_signIconSize])。
  Future<String> _ensureSignImage(
    MapLibreMapController controller,
    int routeNumber,
    RouteStatus status,
    double devicePixelRatio,
  ) async {
    final name = 'route-sign-$routeNumber-${status.name}';
    if (_registeredSignImages.contains(name)) return name;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(devicePixelRatio);
    const size = Size(_signSize, _signSize);
    final path = routeSignPath(size);

    // 本体(ステータス色)と、地図の上で縁を立たせるための白い縁取り。
    canvas.drawPath(path, Paint()..color = _statusColor[status]!);
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    final text = TextPainter(
      text: TextSpan(
        text: '国道\n$routeNumber',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: routeNumber >= 100 ? 9.5 : 10.5,
          height: 1.05,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    // RouteSignBadge の Alignment(0, -0.45) と同じ位置(下が尖っている分、上寄り)。
    final top = (size.height - text.height) / 2 * (1 - 0.45);
    text.paint(canvas, Offset((size.width - text.width) / 2, top));

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width * devicePixelRatio).round(),
      (size.height * devicePixelRatio).round(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bytes == null) return name;

    await controller.addImage(name, bytes.buffer.asUint8List());
    _registeredSignImages.add(name);
    return name;
  }

  /// 日本の陸地の輪郭を、ベクトルタイル由来の層より下に差し込む。
  ///
  /// ベクトルタイルはズーム4未満では配信されないため、引きの俯瞰ではこの層だけが
  /// 背景として見える。寄るとタイルの陸・海が上に重なり、この層は消えていく
  /// ([_silhouetteOpacity])。必ず [belowLayerId] でタイルの層の下に入れること。
  /// 後から追加した層は既定では最前面に積まれるため、指定を忘れると地図を塗り潰す。
  Future<void> _addLandSilhouette(MapLibreMapController controller) async {
    final Map<String, dynamic> geojson;
    try {
      final raw = await rootBundle.loadString('assets/map/japan_land.geojson');
      geojson = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // アセットが無い場合は輪郭なしで続行する(路線・マーカーの表示は妨げない)。
      return;
    }
    try {
      await controller.addGeoJsonSource(_landSourceId, geojson);
      await controller.addFillLayer(
        _landSourceId,
        _landFillLayerId,
        const FillLayerProperties(fillColor: _landHexColor, fillOpacity: _silhouetteOpacity),
        belowLayerId: _landTileLayerId,
      );
      await controller.addLineLayer(
        _landSourceId,
        _landLineLayerId,
        const LineLayerProperties(
          lineColor: _coastHexColor,
          lineWidth: 0.8,
          lineOpacity: _silhouetteOpacity,
        ),
        belowLayerId: _landTileLayerId,
      );
    } catch (_) {
      // スタイルの再読み込みなどで既に追加済みの場合は無視する。
    }
  }

  void _handleCircleTapped(Circle circle) {
    final regionName = circle.data?['region'] as String?;
    if (regionName == null) return;
    final region = RegionKey.values.byName(regionName);
    widget.onSelectRegion(widget.activeRegion == region ? null : region);
  }

  /// 標識画像を表示するときの倍率。[_ensureSignImage] の解像度の扱いを参照。
  double _signIconSize(double devicePixelRatio) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return 1.0;
    return 1.0 / devicePixelRatio;
  }

  /// 現在の路線リスト・ステータス・選択中の地方に合わせてマーカー・路線を描き直す。
  Future<void> _syncMarkers() async {
    if (_syncing) {
      _syncRequested = true;
      return;
    }
    _syncing = true;
    try {
      await _syncMarkersNow();
    } finally {
      _syncing = false;
      if (_syncRequested) {
        _syncRequested = false;
        await _syncMarkers();
      }
    }
  }

  Future<void> _syncMarkersNow() async {
    final controller = _controller;
    if (controller == null) return;
    if (!mounted) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);

    if (_startCircleByRouteId.isNotEmpty) {
      await controller.removeCircles(_startCircleByRouteId.values);
      _startCircleByRouteId.clear();
    }
    if (_goalCircleByRouteId.isNotEmpty) {
      await controller.removeCircles(_goalCircleByRouteId.values);
      _goalCircleByRouteId.clear();
    }
    if (_circleByRegion.isNotEmpty) {
      await controller.removeCircles(_circleByRegion.values);
      _circleByRegion.clear();
    }
    await _clearRouteLines(controller);

    // マーカーの下に敷く形で、各路線の実際の道なりを先に描画する。
    await _syncRouteLines(controller);

    // 先に8地方の常時タップ可能なマーカー（路線が無くても選択できる）を描く。
    // 文字(地方名)はレイヤー側([_regionLabelLayerId])で描く。
    final regionLabelFeatures = <Map<String, dynamic>>[];
    for (final entry in _regionCenters.entries) {
      // 全画面を閉じるなどで描画中に破棄されたら、以降の地図操作はやめる。
      if (!mounted) return;
      final region = entry.key;
      final selected = widget.activeRegion == region;
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: entry.value,
          circleColor: selected ? '#2FA9FF' : '#B9C6CE',
          circleRadius: selected ? 15 : 12,
          circleOpacity: selected ? 0.55 : 0.35,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 1.2,
        ),
        {'region': region.name},
      );
      _circleByRegion[region] = circle;
      regionLabelFeatures.add(_pointFeature(entry.value, {'label': _regionShortLabel[region]}));
    }

    // その上に、実際の路線の起点・終点マーカー（ステータス別に色分け）を重ねて描く。
    // 起点=小さな色付きの丸(タップ用。常時表示)。寄ると([_signMinZoom]以上)その上に
    //      路線番号入りの国道標識が立ち、尖った下端が起点を指す。
    // 終点(ゴール)=白地に色付きの太い縁取りの円。
    final signFeatures = <Map<String, dynamic>>[];
    for (final route in widget.routes) {
      if (!mounted) return;
      final status = widget.statusOf(route.routeId);
      final selected = widget.activeRegion == route.region;
      final color = _statusHexColor[status];
      final data = {'routeId': route.routeId, 'region': route.region.name};
      final start = LatLng(route.startPoint.lat, route.startPoint.lng);

      final startCircle = await controller.addCircle(
        CircleOptions(
          geometry: start,
          circleColor: color,
          circleRadius: selected ? 9 : 7,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: selected ? 2.5 : 1.5,
          circleOpacity: 0.95,
        ),
        data,
      );
      _startCircleByRouteId[route.routeId] = startCircle;

      final imageName = await _ensureSignImage(controller, route.routeNumber, status, dpr);
      signFeatures.add(_pointFeature(start, {
        'icon': imageName,
        'size': (selected ? 1.15 : 1.0) * _signIconSize(dpr),
      }));

      final goalCircle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(route.endPoint.lat, route.endPoint.lng),
          circleColor: '#FFFFFF',
          circleRadius: selected ? 8 : 6,
          circleStrokeColor: color,
          circleStrokeWidth: selected ? 3.0 : 2.2,
          circleOpacity: 0.95,
        ),
        {...data, 'kind': 'goal'},
      );
      _goalCircleByRouteId[route.routeId] = goalCircle;
    }

    if (!mounted) return;
    if (!_overlayLayersReady) await _ensureOverlayLayers(controller);
    try {
      await controller.setGeoJsonSource(
        _regionLabelSourceId,
        {'type': 'FeatureCollection', 'features': regionLabelFeatures},
      );
      await controller.setGeoJsonSource(
        _routeSignSourceId,
        {'type': 'FeatureCollection', 'features': signFeatures},
      );
    } catch (_) {
      // レイヤー作成に失敗している場合。丸マーカーと路線は描けているので続行する。
    }
  }

  /// 走破・地図コレクション画面の下部リストで路線が選ばれたときに、
  /// 地図カメラをその路線の位置（起点・終点の中間点）へ移動させる。
  /// 路線の総距離に応じてズームレベルを大まかに変える（短い路線ほど寄る）。
  Future<void> focusOnRoute(NationalRoute route) async {
    final controller = _controller;
    if (controller == null) return;

    final centerLat = (route.startPoint.lat + route.endPoint.lat) / 2;
    final centerLng = (route.startPoint.lng + route.endPoint.lng) / 2;

    final km = route.totalDistanceKm;
    final double zoom;
    if (km <= 1) {
      zoom = 14;
    } else if (km <= 10) {
      zoom = 12;
    } else if (km <= 50) {
      zoom = 9.5;
    } else if (km <= 150) {
      zoom = 7.5;
    } else if (km <= 400) {
      zoom = 6.2;
    } else {
      zoom = 5.2;
    }

    await controller.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(centerLat, centerLng), zoom),
    );
  }

  /// 以前描画した路線ライン（ソース・レイヤー）をすべて取り除く。
  /// レイヤーを先に消してからソースを消す必要があるため、この順番を守る。
  Future<void> _clearRouteLines(MapLibreMapController controller) async {
    for (final layerId in _lineLayerIds) {
      try {
        await controller.removeLayer(layerId);
      } catch (_) {
        // レイヤーが既に無い場合などは無視する。
      }
    }
    _lineLayerIds.clear();
    for (final sourceId in _lineSourceIds) {
      try {
        await controller.removeSource(sourceId);
      } catch (_) {
        // ソースが既に無い場合などは無視する。
      }
    }
    _lineSourceIds.clear();
  }

  /// 各路線の `geojsonPath` からGeoJSONを読み込み、ステータス色の線として描画する。
  /// アセットがまだ存在しない路線は読み込みに失敗するため、その路線の線だけを
  /// 静かに省略する（他の路線やマーカー表示には影響させない）。
  Future<void> _syncRouteLines(MapLibreMapController controller) async {
    for (final route in widget.routes) {
      if (!mounted) return;
      if (route.geojsonPath.isEmpty) continue;

      final Map<String, dynamic> geojson;
      try {
        final raw = await rootBundle.loadString(route.geojsonPath);
        geojson = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {
        continue;
      }

      final status = widget.statusOf(route.routeId);
      final selected = widget.activeRegion == route.region;
      final sourceId = 'route-line-src-${route.routeId}';
      final layerId = 'route-line-${route.routeId}';
      try {
        await controller.addGeoJsonSource(sourceId, geojson);
        await controller.addLineLayer(
          sourceId,
          layerId,
          LineLayerProperties(
            lineColor: _statusHexColor[status],
            lineWidth: selected ? 3.0 : 2.0,
            lineOpacity: 0.85,
            lineCap: 'round',
            lineJoin: 'round',
          ),
          // 地方ラベル・国道標識の下に入れる(路線の線が標識の上に被らないように)。
          belowLayerId: _overlayLayersReady ? _regionLabelLayerId : null,
        );
        _lineSourceIds.add(sourceId);
        _lineLayerIds.add(layerId);
      } catch (_) {
        // このアセットの追加に失敗した場合は静かに無視する。
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onRequestFullscreen = widget.onRequestFullscreen;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          MapLibreMap(
            styleString: _mapStyle,
            initialCameraPosition: _initialCamera,
            onMapCreated: _onMapCreated,
            onStyleLoadedCallback: _onStyleLoaded,
            myLocationEnabled: false,
            compassEnabled: false,
            // 北固定。小さなパネルでピンチすると意図せず回転・傾斜してしまい、
            // 元に戻しづらいため、拡大縮小と移動だけを許可する。
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            // 日本全体(3.9)より引かない、街区レベルより寄らない。
            minMaxZoomPreference: const MinMaxZoomPreference(3.5, 15),
            // マーカー以外の場所のタップは全画面表示の合図にする。
            // (マーカーのタップは onCircleTapped が先に受け取る。)
            onMapClick: onRequestFullscreen == null ? null : (_, _) => onRequestFullscreen(),
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          ),
          if (onRequestFullscreen != null)
            Positioned(
              right: 6,
              top: 6,
              child: GestureDetector(
                onTap: onRequestFullscreen,
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Color(0x22000000), blurRadius: 4, offset: Offset(0, 1)),
                    ],
                  ),
                  child: const Icon(Icons.open_in_full, size: 15, color: Color(0xFF5C6F7D)),
                ),
              ),
            ),
          // 地理院ベクトルタイルの利用条件である出典の記載。MapLibre の帰属ボタンは
          // タップしないと中身が見えないため、常時見える形で別途置いている。
          Positioned(
            right: 6,
            bottom: 4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  '出典：国土地理院ベクトルタイル',
                  style: TextStyle(fontSize: 9, color: Color(0xFF5F6B75)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
