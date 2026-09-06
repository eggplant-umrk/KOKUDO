import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';

/// 走破・地図コレクション画面用の実地図パネル（MapLibre GL）。
///
/// 各国道の起点にステータス別の色分けされたマーカー（未走破=グレー、
/// 挑戦中=ネオンブルー、完走=ゴールド）を表示する。マーカーをタップすると
/// その路線が属する地方でフィルターできる（もう一度タップで解除）。
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

/// ネオンブルー（挑戦中）はブランドの標識ブルーより彩度を上げた色を使う。
const Map<RouteStatus, String> _statusHexColor = {
  RouteStatus.notStarted: '#CFDBE2',
  RouteStatus.inProgress: '#2FA9FF',
  RouteStatus.completed: '#FFB238',
};

class _JapanMapPanelState extends State<JapanMapPanel> {
  MapLibreMapController? _controller;
  final Map<String, Circle> _circleByRouteId = {};

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
    _controller?.onCircleTapped.remove(_handleCircleTapped);
    super.dispose();
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onCircleTapped.add(_handleCircleTapped);
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

  /// 現在の路線リスト・ステータス・選択中の地方に合わせてマーカーを描き直す。
  Future<void> _syncMarkers() async {
    final controller = _controller;
    if (controller == null) return;

    if (_circleByRouteId.isNotEmpty) {
      await controller.removeCircles(_circleByRouteId.values);
      _circleByRouteId.clear();
    }

    for (final route in widget.routes) {
      final status = widget.statusOf(route.routeId);
      final selected = widget.activeRegion == route.region;
      final circle = await controller.addCircle(
        CircleOptions(
          geometry: LatLng(route.startPoint.lat, route.startPoint.lng),
          circleColor: _statusHexColor[status],
          circleRadius: selected ? 9 : 7,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: selected ? 2.5 : 1.5,
          circleOpacity: 0.95,
        ),
        {'routeId': route.routeId, 'region': route.region.name},
      );
      _circleByRouteId[route.routeId] = circle;
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
