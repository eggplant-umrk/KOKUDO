import 'dart:math' as math;

/// 地球を球体と近似し、Haversineの公式で2地点間の直線距離を計算する。
///
/// 引数・戻り値は緯度経度（度）とメートル。
/// GPSの実測では区間ごとの微小移動を積算していく用途を想定している。
double haversineDistanceMeters(
  double startLat,
  double startLng,
  double endLat,
  double endLng,
) {
  const earthRadiusMeters = 6371000.0;

  final dLat = _degToRad(endLat - startLat);
  final dLng = _degToRad(endLng - startLng);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(startLat)) *
          math.cos(_degToRad(endLat)) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

  return earthRadiusMeters * c;
}

double _degToRad(double deg) => deg * (math.pi / 180);
