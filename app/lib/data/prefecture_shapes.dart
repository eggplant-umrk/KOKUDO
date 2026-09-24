import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter/services.dart' show rootBundle;

/// 都道府県の輪郭。完走シェア画像で、走った国道が通る県の形を
/// 透かしとして敷くために使う。
///
/// 元データは Natural Earth 1:10m Admin 1(パブリックドメイン)。
/// `KOKUDO画像/map_data/build_prefecture_shapes.mjs` で、外周リングだけを
/// 取り出し・主要な島に絞り・Douglas-Peuckerで間引いたものを同梱している
/// (47都道府県で109リング・3844点・72KB)。
///
/// 1点は `Offset(経度, 緯度)`。緯度経度をそのまま持つので、描く側が
/// 路線の線と同じ投影をかけること。
class PrefectureShapes {
  PrefectureShapes._();

  static const String assetPath = 'assets/routes/prefecture_shapes.json';

  /// 読み込み済みの輪郭。読み込みに失敗した場合も空マップを入れて、
  /// 二度目以降は読みに行かない(透かし無しで動く)。
  static Map<String, List<List<Offset>>>? _cache;

  static Future<void> load() async {
    if (_cache != null) return;
    final shapes = <String, List<List<Offset>>>{};
    try {
      final raw = await rootBundle.loadString(assetPath);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final src = (doc['shapes'] as Map<String, dynamic>?) ?? const {};
      for (final entry in src.entries) {
        final rings = <List<Offset>>[];
        for (final ring in (entry.value as List)) {
          final points = <Offset>[];
          for (final point in (ring as List)) {
            final pair = (point as List).cast<num>();
            points.add(Offset(pair[0].toDouble(), pair[1].toDouble()));
          }
          // 3点未満は面にならないので捨てる。
          if (points.length >= 3) rings.add(points);
        }
        if (rings.isNotEmpty) shapes[entry.key] = rings;
      }
    } catch (_) {
      // アセットが無い・壊れている場合は透かし無しで続ける。
    }
    _cache = shapes;
  }

  /// [prefectureNames](「北海道」「神奈川県」など)の輪郭をまとめて返す。
  /// [load] より前に呼んだ場合と、知らない県名は空になる。
  static List<List<Offset>> ringsOf(Iterable<String> prefectureNames) {
    final shapes = _cache;
    if (shapes == null) return const [];
    final rings = <List<Offset>>[];
    for (final name in prefectureNames) {
      final found = shapes[name];
      if (found != null) rings.addAll(found);
    }
    return rings;
  }
}
