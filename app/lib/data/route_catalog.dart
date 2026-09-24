import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;
import 'package:meta/meta.dart';

import '../models/national_route.dart';
import '../models/route_checkpoint.dart';

/// 全国道(459路線)のマスターデータを `assets/routes/national_routes.json` から
/// 読み込む。
///
/// JSONの出どころ(詳細はJSON冒頭の `sources`):
/// - 起点・終点の名前と順序: 一般国道の路線を指定する政令(e-Gov 法令API)
/// - 起点・終点の座標と延長: Wikidata(CC0)。座標は市区町村の代表点なので概略位置
/// - 地方: 起点の座標から国土地理院の逆ジオコーダーで都道府県を求めて8地方に分類
/// - 先行6路線(1, 4, 130, 134, 174, 292号): 運営が指定した実地点・チェックポイント・
///   難易度・おすすめ文をそのまま使う。距離だけは他路線と同じ総延長に揃えてある
///
/// 完走判定は距離の積み上げなので、路線の線(GeoJSON)が無くても挑戦できる。
/// 線は `geojson_path` がある路線だけ地図に描かれ、順次追加する。
class RouteCatalog {
  RouteCatalog._();

  static const String assetPath = 'assets/routes/national_routes.json';

  /// 都道府県の表示範囲(検索時に地図を寄せる用)。無くてもアプリは動く。
  static const String prefectureBoundsAssetPath = 'assets/routes/prefecture_bounds.json';
  static final Map<String, List<double>> _prefectureBounds = {};

  /// [name](「神奈川県」など)の範囲 `[minLng, minLat, maxLng, maxLat]`。
  /// 本土側のいちばん大きい島の範囲で、離島は含まない。未読み込み・不明なら null。
  static List<double>? prefectureBounds(String name) => _prefectureBounds[name];

  static List<NationalRoute>? _cache;
  static int? _version;
  static final Map<String, List<String>> _prefecturesByRoute = {};

  /// 路線が通る都道府県(JSONの `prefectures`。Wikidata P131 と起点・終点の
  /// 逆ジオコーディングから作成)。DBには入れず、検索用にメモリ上だけで持つ。
  /// [load] 前に呼ぶと空のリストを返す。
  static List<String> prefecturesOf(String routeId) => _prefecturesByRoute[routeId] ?? const [];

  /// JSONの `version`。増えたら [RouteRepository] が DB のマスターデータを入れ直す。
  static Future<int> version() async {
    await load();
    return _version!;
  }

  static Future<List<NationalRoute>> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    await _loadPrefectureBounds();

    final raw = await rootBundle.loadString(assetPath);
    final routes = parseDocument(jsonDecode(raw) as Map<String, dynamic>);
    _cache = routes;
    return routes;
  }

  /// JSON全体(`{"version":..,"routes":[..]}`)から路線一覧を組み立てる。
  ///
  /// [load] の中身をそのまま切り出したもの。アセットを差し替えられない
  /// テストから、壊れた路線が混ざったときの挙動を確かめるために公開している。
  /// 1路線の不備で全路線が読めなくなるより、その路線だけ飛ばす。
  @visibleForTesting
  static List<NationalRoute> parseDocument(Map<String, dynamic> doc) {
    _version = (doc['version'] as num?)?.toInt() ?? 1;
    final routes = <NationalRoute>[];
    for (final item in (doc['routes'] as List? ?? const [])) {
      try {
        routes.add(_fromJson(item as Map<String, dynamic>));
      } catch (e) {
        assert(() {
          debugPrint('RouteCatalog: 路線を読み飛ばしました: $e');
          return true;
        }());
      }
    }
    routes.sort((a, b) => a.routeNumber.compareTo(b.routeNumber));
    return routes;
  }

  /// 読み込み済みの内容をすべて捨てる。テストごとにまっさらな状態から
  /// 読み直せるようにするためのもの。
  @visibleForTesting
  static void resetForTesting() {
    _cache = null;
    _version = null;
    _prefecturesByRoute.clear();
    _prefectureBounds.clear();
  }

  static Future<void> _loadPrefectureBounds() async {
    if (_prefectureBounds.isNotEmpty) return;
    try {
      final raw = await rootBundle.loadString(prefectureBoundsAssetPath);
      final doc = jsonDecode(raw) as Map<String, dynamic>;
      final bounds = (doc['bounds'] as Map<String, dynamic>?) ?? const {};
      for (final entry in bounds.entries) {
        final box = (entry.value as List).cast<num>().map((v) => v.toDouble()).toList();
        if (box.length == 4) _prefectureBounds[entry.key] = box;
      }
    } catch (_) {
      // アセットが無い・壊れている場合は範囲なしで続行する(検索結果の点に寄せる)。
    }
  }

  static NationalRoute _fromJson(Map<String, dynamic> j) {
    final number = (j['route_number'] as num).toInt();
    final routeId = '$number';
    _prefecturesByRoute[routeId] = ((j['prefectures'] as List?) ?? const []).cast<String>();
    final totalKm = (j['total_distance_km'] as num).toDouble();
    final start = j['start'] as Map<String, dynamic>;
    final end = j['end'] as Map<String, dynamic>;

    final checkpoints = ((j['checkpoints'] as List?) ?? const [])
        .cast<Map<String, dynamic>>()
        .map((c) => RouteCheckpoint(
              checkpointId: c['checkpoint_id'] as String,
              routeId: routeId,
              name: c['name'] as String,
              distanceKmFromStart: (c['distance_km_from_start'] as num).toDouble(),
              orderIndex: (c['order_index'] as num).toInt(),
              lat: (c['lat'] as num?)?.toDouble(),
              lng: (c['lng'] as num?)?.toDouble(),
            ))
        .toList();

    final difficultyName = j['difficulty'] as String?;
    final difficulty = RouteDifficulty.values.asNameMap()[difficultyName] ?? difficultyForDistance(totalKm);
    final startLabel = start['label'] as String?;
    final endLabel = end['label'] as String?;

    return NationalRoute(
      routeId: routeId,
      routeNumber: number,
      name: j['name'] as String,
      startPoint: RoutePoint(
        lat: (start['lat'] as num).toDouble(),
        lng: (start['lng'] as num).toDouble(),
        label: startLabel,
      ),
      endPoint: RoutePoint(
        lat: (end['lat'] as num).toDouble(),
        lng: (end['lng'] as num).toDouble(),
        label: endLabel,
      ),
      totalDistanceKm: totalKm,
      geojsonPath: (j['geojson_path'] as String?) ?? '',
      region: RegionKey.values.byName(j['region'] as String),
      difficulty: difficulty,
      recommendReason: (j['recommend_reason'] as String?) ??
          _defaultRecommendReason(startLabel ?? '起点', endLabel ?? '終点', totalKm, difficulty),
      checkpoints: checkpoints,
    );
  }

  /// 手書きの難易度が無い路線は、総延長から機械的に決める。
  /// 先行6路線の割り当て(0.5km=tutorial, 61km=beginner, 118km=intermediate,
  /// 565km=advanced, 744km=challenge)と矛盾しない境界にしてある。
  static RouteDifficulty difficultyForDistance(double km) {
    if (km < 3) return RouteDifficulty.tutorial;
    if (km <= 80) return RouteDifficulty.beginner;
    if (km <= 200) return RouteDifficulty.intermediate;
    if (km <= 600) return RouteDifficulty.advanced;
    return RouteDifficulty.challenge;
  }

  static const Map<RouteDifficulty, String> _difficultyLabel = {
    RouteDifficulty.tutorial: '即日クリアできるチュートリアル向け',
    RouteDifficulty.beginner: '初級・数週間の目標に',
    RouteDifficulty.intermediate: '中級・1〜2か月の目標に',
    RouteDifficulty.advanced: '上級・数か月かけて挑む',
    RouteDifficulty.challenge: '年間チャレンジ級',
  };

  static String _defaultRecommendReason(String start, String end, double km, RouteDifficulty d) {
    final kmText = km < 1 ? '${(km * 1000).round()}m' : '${km.toStringAsFixed(km < 10 ? 1 : 0)}km';
    return '$start → $end、全長$kmText。${_difficultyLabel[d]}。';
  }
}
