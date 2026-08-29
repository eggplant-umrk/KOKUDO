import 'route_checkpoint.dart';

/// 国道の起点・終点を表す座標。
class RoutePoint {
  final double lat;
  final double lng;
  final String? label;

  const RoutePoint({required this.lat, required this.lng, this.label});
}

/// 国道マスターデータ（全459路線分の器を想定）。
class NationalRoute {
  final String routeId;
  final int routeNumber;
  final String name;
  final RoutePoint startPoint;
  final RoutePoint endPoint;
  final double totalDistanceKm;

  /// 端末内に保持するGeoJSONファイルへのパス（asset or ローカルストレージ）。
  final String geojsonPath;

  final List<RouteCheckpoint> checkpoints;

  const NationalRoute({
    required this.routeId,
    required this.routeNumber,
    required this.name,
    required this.startPoint,
    required this.endPoint,
    required this.totalDistanceKm,
    required this.geojsonPath,
    this.checkpoints = const [],
  });

  factory NationalRoute.fromMap(
    Map<String, Object?> map, {
    List<RouteCheckpoint> checkpoints = const [],
  }) {
    return NationalRoute(
      routeId: map['route_id'] as String,
      routeNumber: map['route_number'] as int,
      name: map['name'] as String,
      startPoint: RoutePoint(
        lat: (map['start_lat'] as num).toDouble(),
        lng: (map['start_lng'] as num).toDouble(),
        label: map['start_label'] as String?,
      ),
      endPoint: RoutePoint(
        lat: (map['end_lat'] as num).toDouble(),
        lng: (map['end_lng'] as num).toDouble(),
        label: map['end_label'] as String?,
      ),
      totalDistanceKm: (map['total_distance_km'] as num).toDouble(),
      geojsonPath: map['geojson_path'] as String,
      checkpoints: checkpoints,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'route_id': routeId,
      'route_number': routeNumber,
      'name': name,
      'start_lat': startPoint.lat,
      'start_lng': startPoint.lng,
      'start_label': startPoint.label,
      'end_lat': endPoint.lat,
      'end_lng': endPoint.lng,
      'end_label': endPoint.label,
      'total_distance_km': totalDistanceKm,
      'geojson_path': geojsonPath,
    };
  }
}
