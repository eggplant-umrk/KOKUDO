/// [NationalRoute] 上に設定されるチェックポイント（区間の目印地点）。
class RouteCheckpoint {
  final String checkpointId;
  final String routeId;
  final String name;
  final double distanceKmFromStart;
  final int orderIndex;
  final double? lat;
  final double? lng;

  const RouteCheckpoint({
    required this.checkpointId,
    required this.routeId,
    required this.name,
    required this.distanceKmFromStart,
    required this.orderIndex,
    this.lat,
    this.lng,
  });

  factory RouteCheckpoint.fromMap(Map<String, Object?> map) {
    return RouteCheckpoint(
      checkpointId: map['checkpoint_id'] as String,
      routeId: map['route_id'] as String,
      name: map['name'] as String,
      distanceKmFromStart: (map['distance_km_from_start'] as num).toDouble(),
      orderIndex: map['order_index'] as int,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'checkpoint_id': checkpointId,
      'route_id': routeId,
      'name': name,
      'distance_km_from_start': distanceKmFromStart,
      'order_index': orderIndex,
      'lat': lat,
      'lng': lng,
    };
  }
}
