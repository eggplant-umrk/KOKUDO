// 同梱の national_routes.json(459路線)を実際に読み込んで、カタログの
// 読み取りが期待どおりかを確認する。
//
// 実データそのものを検証対象にしているので、JSONを作り直したときに
// 路線が抜けた・必須フィールドが欠けたといった事故に気づける。
// カタログが壊れるとアプリは路線ゼロで起動できなくなるが、症状が出るのは
// 起動時なので、テストで先に止めたい。
import 'package:flutter_test/flutter_test.dart';

import 'package:kokudo/data/prefecture_shapes.dart';
import 'package:kokudo/data/route_catalog.dart';
import 'package:kokudo/models/national_route.dart';

/// 最小限の路線1件分のJSON。壊れた路線の扱いを見るために使う。
Map<String, dynamic> _routeJson(int number) => {
      'route_number': number,
      'name': '国道$number号',
      'total_distance_km': 100.0,
      'start': {'lat': 35.0, 'lng': 139.0, 'label': '起点'},
      'end': {'lat': 34.0, 'lng': 135.0, 'label': '終点'},
      'region': 'kanto',
      'prefectures': ['東京都'],
    };

void main() {
  // 素の test() なので、rootBundle を使う前にバインディングを張っておく。
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(RouteCatalog.resetForTesting);

  group('同梱JSONの読み込み', () {
    test('459路線が路線番号順・重複なしで読める', () async {
      final routes = await RouteCatalog.load();

      expect(routes, hasLength(459));
      final numbers = routes.map((r) => r.routeNumber).toList();
      expect(numbers, equals([...numbers]..sort()));
      expect(numbers.toSet(), hasLength(numbers.length));
    });

    test('どの路線も名前・起終点・距離・地方が埋まっている', () async {
      final routes = await RouteCatalog.load();

      for (final route in routes) {
        final where = '国道${route.routeNumber}号';
        expect(route.routeId, '${route.routeNumber}', reason: where);
        expect(route.name, isNotEmpty, reason: where);
        expect(route.totalDistanceKm, greaterThan(0), reason: where);
        expect(route.startPoint.label, isNotNull, reason: where);
        expect(route.endPoint.label, isNotNull, reason: where);
        expect(route.recommendReason, isNotEmpty, reason: where);
      }
    });

    test('versionは1以上(DBのマスター入れ直しの判定に使う)', () async {
      expect(await RouteCatalog.version(), greaterThanOrEqualTo(1));
    });
  });

  group('壊れた路線の扱い', () {
    test('必須フィールドが欠けた路線だけを飛ばして、残りは読める', () {
      final routes = RouteCatalog.parseDocument({
        'version': 7,
        'routes': [
          _routeJson(1),
          {'route_number': 2}, // 名前も起終点も距離も無い
          _routeJson(3),
        ],
      });

      expect(routes.map((r) => r.routeNumber), [1, 3]);
    });

    test('routesが無ければ空のリストになる(例外にはしない)', () {
      expect(RouteCatalog.parseDocument({'version': 1}), isEmpty);
    });
  });

  group('難易度の割り当て', () {
    test('総延長の境界で切り替わる', () {
      expect(RouteCatalog.difficultyForDistance(0.187), RouteDifficulty.tutorial);
      expect(RouteCatalog.difficultyForDistance(2.999), RouteDifficulty.tutorial);
      expect(RouteCatalog.difficultyForDistance(3), RouteDifficulty.beginner);
      expect(RouteCatalog.difficultyForDistance(80), RouteDifficulty.beginner);
      expect(RouteCatalog.difficultyForDistance(80.1), RouteDifficulty.intermediate);
      expect(RouteCatalog.difficultyForDistance(200), RouteDifficulty.intermediate);
      expect(RouteCatalog.difficultyForDistance(200.1), RouteDifficulty.advanced);
      expect(RouteCatalog.difficultyForDistance(600), RouteDifficulty.advanced);
      expect(RouteCatalog.difficultyForDistance(600.1), RouteDifficulty.challenge);
    });
  });

  group('都道府県', () {
    test('国道1号は東京都から大阪府までの8都府県を政令の順で返す', () async {
      await RouteCatalog.load();

      expect(RouteCatalog.prefecturesOf('1'), [
        '東京都',
        '神奈川県',
        '静岡県',
        '愛知県',
        '三重県',
        '滋賀県',
        '京都府',
        '大阪府',
      ]);
    });

    test('load前は空を返す(呼び出し順に関わらず落ちない)', () {
      expect(RouteCatalog.prefecturesOf('1'), isEmpty);
    });

    test('表示範囲は[minLng, minLat, maxLng, maxLat]の4要素', () async {
      await RouteCatalog.load();

      final box = RouteCatalog.prefectureBounds('神奈川県');
      expect(box, isNotNull);
      expect(box!, hasLength(4));
      expect(box[0], lessThan(box[2]));
      expect(box[1], lessThan(box[3]));
    });

    test('カタログに出てくる県名は、すべて透かし用の輪郭データにも存在する', () async {
      final routes = await RouteCatalog.load();
      await PrefectureShapes.load();

      final names = <String>{
        for (final route in routes) ...RouteCatalog.prefecturesOf(route.routeId),
      };
      expect(names, hasLength(47));
      for (final name in names) {
        // 完走シェア画像の透かしはこの名前で輪郭を引く。名前がずれると
        // 透かしだけが静かに消えるので、ここで突き合わせておく。
        expect(PrefectureShapes.ringsOf([name]), isNotEmpty, reason: '$name の輪郭が無い');
      }
    });
  });
}
