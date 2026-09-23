import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart' show rootBundle;

/// 路線の道なりの線(GeoJSON)を、描画しやすい形に変換して読む。
///
/// 地図パネル(JapanMapPanel)は MapLibre にそのまま渡すので GeoJSON の
/// Map のまま持っているが、シェア画像は自前で描くので座標の配列が要る。
/// 1点は `Offset(経度, 緯度)`。
class RouteGeometry {
  RouteGeometry._();

  /// キーは `NationalRoute.geojsonPath`。読めなかった路線は空リストを覚えて
  /// おき、二度目以降は読みに行かない。
  static final Map<String, List<List<Offset>>> _cache = {};

  static Future<List<List<Offset>>> load(String assetPath) async {
    if (assetPath.isEmpty) return const [];
    final cached = _cache[assetPath];
    if (cached != null) return cached;

    var lines = <List<Offset>>[];
    try {
      final raw = await rootBundle.loadString(assetPath, cache: false);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final features = doc['features'] as List?;
      final geometries = <Map<String, dynamic>>[];
      if (features != null) {
        for (final feature in features) {
          final geometry = (feature as Map<String, dynamic>)['geometry'];
          if (geometry is Map<String, dynamic>) geometries.add(geometry);
        }
      } else if (doc['geometry'] is Map<String, dynamic>) {
        geometries.add(doc['geometry'] as Map<String, dynamic>);
      }
      for (final geometry in geometries) {
        switch (geometry['type']) {
          case 'LineString':
            lines.add(_toPoints(geometry['coordinates'] as List));
          case 'MultiLineString':
            for (final part in (geometry['coordinates'] as List)) {
              lines.add(_toPoints(part as List));
            }
        }
      }
      lines = lines.where((line) => line.length >= 2).toList(growable: false);
    } catch (_) {
      lines = const [];
    }
    _cache[assetPath] = lines;
    return lines;
  }

  static List<Offset> _toPoints(List coordinates) {
    final points = <Offset>[];
    for (final coordinate in coordinates) {
      final pair = (coordinate as List).cast<num>();
      points.add(Offset(pair[0].toDouble(), pair[1].toDouble()));
    }
    return points;
  }
}
