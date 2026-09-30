// カタログ(同梱JSON)を端末内SQLiteへ流し込む処理の確認。
//
// ここが壊れると「路線が1件も無くて起動できない」か、あるいは
// 「完走したのに93%と表示される」といった形で出る。後者は例外も出ず、
// 総距離を実延長に差し替えたときにだけ起きるので、テストで押さえておく。
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kokudo/data/app_database.dart';
import 'package:kokudo/data/auth_repository.dart';
import 'package:kokudo/data/route_catalog.dart';
import 'package:kokudo/data/route_repository.dart';
import 'package:kokudo/models/national_route.dart';
import 'package:kokudo/models/user_route_progress.dart';

/// DBに記録されたカタログの版。RouteRepository側の定数と同じ値。
const String _versionSettingKey = 'route_catalog_version';

/// [routeId] の進捗を、指定した距離・完走状態で置き換える。
Future<void> _putProgress(
  RouteRepository repo,
  String routeId, {
  required double distanceKm,
  required bool completed,
}) async {
  final now = DateTime(2026, 9, 24);
  await repo.saveProgress(UserRouteProgress(
    userId: RouteRepository.currentUserId,
    routeId: routeId,
    currentDistanceKm: distanceKm,
    targetEndDate: now,
    isCompleted: completed,
    startedAt: now,
    completedAt: completed ? now : null,
    updatedAt: now,
  ));
}

/// 版の記録を消して、次の [RouteRepository.ensureSeeded] でマスターの
/// 入れ直しが走るようにする(JSONのversionを上げたのと同じ状況を作る)。
Future<void> _forceCatalogResync(RouteRepository repo) async {
  final db = await AppDatabase.instance.database;
  await db.delete('app_settings', where: 'key = ?', whereArgs: [_versionSettingKey]);
  repo.resetSeedCacheForTesting();
  await repo.ensureSeeded();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // テストファイルごとに別プロセスで走るので、同じDBファイルを共有すると
    // "database is locked" になることがある。ファイルを使わないDBにする。
    AppDatabase.databasePathOverrideForTesting = inMemoryDatabasePath;
  });

  setUp(() async {
    await AppDatabase.instance.resetForTesting();
    RouteRepository.instance.resetSeedCacheForTesting();
    RouteCatalog.resetForTesting();

    // AuthRepository.instance は読む前に書く(本物のFirebaseAuthを触らない)。
    AuthRepository.instance = AuthRepository.forTesting(
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'test-uid', email: 'test@example.com'),
      ),
    );
  });

  test('シードで459路線がDBに入り、カタログの版が記録される', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();

    expect(await repo.getRoutes(), hasLength(459));

    final db = await AppDatabase.instance.database;
    final rows = await db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [_versionSettingKey],
    );
    expect(rows.single['value'], '${await RouteCatalog.version()}');
  });

  test('入れ直しのとき、完走済みの進捗は新しい総距離に揃えられる', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final NationalRoute route = (await repo.getRoutes()).firstWhere((r) => r.routeId == '1');

    // 総距離とかけ離れた値のまま「完走」にしておく。
    await _putProgress(repo, route.routeId, distanceKm: 1, completed: true);
    await _forceCatalogResync(repo);

    final progress = await repo.getProgress(route.routeId);
    expect(progress, isNotNull);
    expect(progress!.currentDistanceKm, closeTo(route.totalDistanceKm, 0.001));
  });

  test('入れ直しのとき、未完走で総距離を超えている進捗は総距離まで下げられる', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final route = (await repo.getRoutes()).firstWhere((r) => r.routeId == '1');

    await _putProgress(repo, route.routeId, distanceKm: route.totalDistanceKm * 2, completed: false);
    await _forceCatalogResync(repo);

    final progress = await repo.getProgress(route.routeId);
    expect(progress!.currentDistanceKm, closeTo(route.totalDistanceKm, 0.001));
  });

  test('入れ直しのとき、途中までの進捗はそのまま残る', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final route = (await repo.getRoutes()).firstWhere((r) => r.routeId == '1');

    await _putProgress(repo, route.routeId, distanceKm: 12.3, completed: false);
    await _forceCatalogResync(repo);

    final progress = await repo.getProgress(route.routeId);
    expect(progress!.currentDistanceKm, closeTo(12.3, 0.001));
  });
}
