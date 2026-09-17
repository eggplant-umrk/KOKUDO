import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';

/// 走破・地図コレクション画面用の実地図パネル（MapLibre GL）。
///
/// 各国道の起点・終点にステータス別の色分けマーカー（未走破=グレー、
/// 挑戦中=ネオンブルー、完走=ゴールド）を表示する。起点は塗りつぶし円、
/// 終点（ゴール）は白地に色付きの太い縁取りの円で区別する。マーカーを
/// タップするとその路線が属する地方でフィルターできる（もう一度タップで解除）。
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

  const JapanMapPanel({
    super.key,
    required this.routes,
    required this.activeRegion,
    required this.onSelectRegion,
    required this.statusOf,
  });

  @override
  State<JapanMapPanel> createState() => JapanMapPanelState();
}

/// ネオンブルー（挑戦中）はブランドの標識ブルーより彩度を上げた色を使う。
const Map<RouteStatus, String> _statusHexColor = {
  RouteStatus.notStarted: '#CFDBE2',
  RouteStatus.inProgress: '#2FA9FF',
  RouteStatus.completed: '#FFB238',
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

class JapanMapPanelState extends State<JapanMapPanel> {
  MapLibreMapController? _controller;
  final Map<String, Circle> _circleByRouteId = {};
  final Map<String, Circle> _goalCircleByRouteId = {};
  final Map<RegionKey, Circle> _circleByRegion = {};
  final Map<RegionKey, Symbol> _labelByRegion = {};
  final Set<String> _lineLayerIds = {};
  final Set<String> _lineSourceIds = {};

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
    controller?.onSymbolTapped.remove(_handleSymbolTapped);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onCircleTapped.add(_handleCircleTapped);
    controller.onSymbolTapped.add(_handleSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    await _syncMarkers();
  }

  void _handleCircleTapped(Circle circle) {
    final regionName = circle.data?['region'] as String?;
    if (regionName == null) return;
    final region = RegionKey.values.byName(regionName);
    widget.onSelectRegion(widget.activeRegion == region ? null : region);
  }

  void _handleSymbolTapped(Symbol symbol) {
    final regionName = symbol.data?['region'] as String?;
    if (regionName == null) return;
    final region = RegionKey.values.byName(regionName);
    widget.onSelectRegion(widget.activeRegion == region ? null : region);
  }

  /// 現在の路線リスト・ステータス・選択中の地方に合わせてマーカー・路線を描き直す。
  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    if (_circleByRouteId.isNotEmpty) {
      await controller.removeCircles(_circleByRouteId.values);
      _circleByRouteId.clear();
    }
    if (_goalCircleByRouteId.isNotEmpty) {
      await controller.removeCircles(_goalCircleByRouteId.values);
      _goalCircleByRouteId.clear();
    }
    if (_circleByRegion.isNotEmpty) {
      await controller.removeCircles(_circleByRegion.values);
      _circleByRegion.clear();
    }
    if (_labelByRegion.isNotEmpty) {
      await controller.removeSymbols(_labelByRegion.values);
      _labelByRegion.clear();
    }
    await _clearRouteLines(controller);

    // マーカーの下に敷く形で、各路線の実際の道なりを先に描画する。
    await _syncRouteLines(controller);

    // 先に8地方の常時タップ可能なマーカー（路線が無くても選択できる）を描く。
    for (final entry in _regionCenters.entries) {
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

      final symbol = await controller.addSymbol(
        SymbolOptions(
          geometry: entry.value,
          textField: _regionShortLabel[region],
          textSize: 10,
          textColor: '#3C4043',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.2,
          textOffset: const Offset(0, 0),
        ),
        {'region': region.name},
      );
      _labelByRegion[region] = symbol;
    }

    // その上に、実際の路線の起点・終点マーカー（ステータス別に色分け）を重ねて描く。
    // 起点=塗りつぶし円、終点(ゴール)=白地に色付きの太い縁取り、で区別する。
    for (final route in widget.routes) {
      final status = widget.statusOf(route.routeId);
      final selected = widget.activeRegion == route.region;
      final color = _statusHexColor[status];

      final startCircle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(route.startPoint.lat, route.startPoint.lng),
          circleColor: color,
          circleRadius: selected ? 9 : 7,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: selected ? 2.5 : 1.5,
          circleOpacity: 0.95,
        ),
        {'routeId': route.routeId, 'region': route.region.name},
      );
      _circleByRouteId[route.routeId] = startCircle;

      final goalCircle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(route.endPoint.lat, route.endPoint.lng),
          circleColor: '#FFFFFF',
          circleRadius: selected ? 8 : 6,
          circleStrokeColor: color,
          circleStrokeWidth: selected ? 3.0 : 2.2,
          circleOpacity: 0.95,
        ),
        {'routeId': route.routeId, 'region': route.region.name, 'kind': 'goal'},
      );
      _goalCircleByRouteId[route.routeId] = goalCircle;
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
    return SizedBox(
      height: 220,
      // MapLibreデモサーバーの汎用スタイルを使用。
      // TODO: 自前のスタイル/タイルサーバーを用意する場合はここを差し替える。
      child: MapLibreMap(
        styleString: 'https://demotiles.maplibre.org/style.json',
        initialCameraPosition: _initialCamera,
        onMapCreated: _onMapCreated,
        onStyleLoadedCallback: _onStyleLoaded,
        myLocationEnabled: false,
        compassEnabled: false,
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
      ),
    );
  }
}
