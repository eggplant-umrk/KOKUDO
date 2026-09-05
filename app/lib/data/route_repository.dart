import 'package:sqflite/sqflite.dart';

import '../models/national_route.dart';
import '../models/route_checkpoint.dart';
import '../models/run_log.dart';
import '../models/user_route_progress.dart';
import 'app_database.dart';
import 'mock_data.dart' as seed;

/// [AppDatabase]（端末内SQLite）を実データソースとして扱うリポジトリ。
///
/// バックエンド未接続の現段階では、初回起動時のみ mock_data.dart の内容を
/// 初期データとしてDBへ書き込む（デモ用シード）。以降は画面からの読み書きは
/// すべてこのクラス経由でSQLiteに対して行われる。
class RouteRepository {
  RouteRepository._();

  static final RouteRepository instance = RouteRepository._();

  /// 現段階ではログイン機能がないため、単一ユーザーIDを固定で使用する。
  static const String userId = 'usr_123';

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void>? _seedFuture;

  /// national_routes が空の場合のみ、mock_data.dart の内容をシードする。
  /// 複数箇所から同時に呼ばれても二重シードされないよう、Futureをキャッシュする。
  Future<void> ensureSeeded() {
    return _seedFuture ??= _seed();
  }

  Future<void> _seed() async {
    final db = await _db;
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM national_routes'),
    );
    if (count != null && count > 0) return;

    final batch = db.batch();
    for (final route in seed.routes) {
      batch.insert('national_routes', route.toMap());
      for (final checkpoint in route.checkpoints) {
        batch.insert('route_checkpoints', checkpoint.toMap());
      }
    }
    for (final progress in seed.userProgress) {
      batch.insert('user_route_progress', progress.toMap());
    }
    for (final log in seed.runLogs) {
      batch.insert('run_logs', log.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<NationalRoute>> getRoutes() async {
    await ensureSeeded();
    final db = await _db;
    final routeRows = await db.query('national_routes', orderBy: 'route_number');
    final checkpointRows = await db.query('route_checkpoints', orderBy: 'order_index');

    final checkpointsByRoute = <String, List<RouteCheckpoint>>{};
    for (final row in checkpointRows) {
      final checkpoint = RouteCheckpoint.fromMap(row);
      checkpointsByRoute.putIfAbsent(checkpoint.routeId, () => []).add(checkpoint);
    }

    return routeRows
        .map((row) => NationalRoute.fromMap(
              row,
              checkpoints: checkpointsByRoute[row['route_id']] ?? const [],
            ))
        .toList();
  }

  Future<NationalRoute?> getRoute(String routeId) async {
    await ensureSeeded();
    final db = await _db;
    final rows = await db.query('national_routes', where: 'route_id = ?', whereArgs: [routeId]);
    if (rows.isEmpty) return null;

    final checkpointRows = await db.query(
      'route_checkpoints',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'order_index',
    );

    return NationalRoute.fromMap(
      rows.first,
      checkpoints: checkpointRows.map(RouteCheckpoint.fromMap).toList(),
    );
  }

  Future<UserRouteProgress?> getProgress(String routeId) async {
    await ensureSeeded();
    final db = await _db;
    final rows = await db.query(
      'user_route_progress',
      where: 'user_id = ? AND route_id = ?',
      whereArgs: [userId, routeId],
    );
    if (rows.isEmpty) return null;
    return UserRouteProgress.fromMap(rows.first);
  }

  Future<List<UserRouteProgress>> _allProgress() async {
    await ensureSeeded();
    final db = await _db;
    final rows = await db.query('user_route_progress', where: 'user_id = ?', whereArgs: [userId]);
    return rows.map(UserRouteProgress.fromMap).toList();
  }

  Future<void> saveProgress(UserRouteProgress progress) async {
    final db = await _db;
    await db.insert(
      'user_route_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> addRunLog(RunLog log) async {
    final db = await _db;
    await db.insert('run_logs', log.toMap());
  }

  Future<List<RunLog>> getRunLogs() async {
    await ensureSeeded();
    final db = await _db;
    final rows = await db.query('run_logs', where: 'user_id = ?', whereArgs: [userId]);
    return rows.map(RunLog.fromMap).toList();
  }

  /// 一度にチャレンジできるのは1路線のみのため、進捗が付いていても
  /// currentDistanceKm が0より大きい路線だけを「挑戦中」とみなす。
  Future<RouteStatus> routeStatusOf(String routeId) async {
    final progress = await getProgress(routeId);
    if (progress == null) return RouteStatus.notStarted;
    if (progress.isCompleted) return RouteStatus.completed;
    if (progress.currentDistanceKm > 0) return RouteStatus.inProgress;
    return RouteStatus.notStarted;
  }

  /// 現在「挑戦中」（進捗があり未完走）の路線IDを返す。
  /// 見つからない場合は、シードデータの初期アクティブ路線にフォールバックする
  /// （路線選択フローが未実装のため、暫定措置）。
  Future<String> getActiveRouteId() async {
    final all = await _allProgress();
    for (final progress in all) {
      if (!progress.isCompleted && progress.currentDistanceKm > 0) {
        return progress.routeId;
      }
    }
    return seed.activeRouteId;
  }

  Future<int> completedRouteCount() async {
    final all = await _allProgress();
    return all.where((p) => p.isCompleted).length;
  }

  Future<double> cumulativeDistanceKm() async {
    final all = await _allProgress();
    return all.fold<double>(0.0, (sum, p) => sum + p.currentDistanceKm);
  }

  Future<double> coverageRatio() async {
    final cumulative = await cumulativeDistanceKm();
    final ratio = cumulative / seed.nationalNetworkTotalKm;
    return ratio < 1 ? ratio : 1;
  }

  Future<double> todayTotalDistanceKm() async {
    final logs = await getRunLogs();
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    return logs
        .where((l) => !l.recordedAt.isBefore(startOfToday))
        .fold<double>(0.0, (sum, l) => sum + l.distanceKm);
  }

  Future<double> monthTotalDistanceKm() async {
    final logs = await getRunLogs();
    final now = DateTime.now();
    return logs
        .where((l) => l.recordedAt.year == now.year && l.recordedAt.month == now.month)
        .fold<double>(0.0, (sum, l) => sum + l.distanceKm);
  }

  /// ランニング計測画面の終了時に呼ぶ: RunLogを保存し、対象路線の進捗
  /// （currentDistanceKm）に加算する。合計が路線の総距離に達した場合は
  /// isCompleted / completedAt を更新する。
  Future<void> recordRun({
    required String routeId,
    required double distanceKm,
    required int durationSeconds,
    required int caloriesBurned,
  }) async {
    await addRunLog(RunLog(
      logId: 'log_${DateTime.now().microsecondsSinceEpoch}',
      userId: userId,
      routeId: routeId,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      caloriesBurned: caloriesBurned.toDouble(),
      recordedAt: DateTime.now(),
    ));

    final route = await getRoute(routeId);
    final existing = await getProgress(routeId);
    final newDistance = (existing?.currentDistanceKm ?? 0) + distanceKm;
    final isCompleted = route != null && newDistance >= route.totalDistanceKm;

    await saveProgress(UserRouteProgress(
      userId: userId,
      routeId: routeId,
      currentDistanceKm: isCompleted ? route.totalDistanceKm : newDistance,
      targetEndDate: existing?.targetEndDate ?? DateTime.now().add(const Duration(days: 90)),
      runsPerWeekGoal: existing?.runsPerWeekGoal,
      isCompleted: isCompleted,
      startedAt: existing?.startedAt ?? DateTime.now(),
      completedAt: isCompleted ? DateTime.now() : existing?.completedAt,
      clearedCheckpoints: existing?.clearedCheckpoints ?? const [],
    ));
  }

  /// 完走ナビ（目標期日・週間ペース）の変更を保存する。
  Future<void> updateGoal({
    required String routeId,
    required DateTime targetEndDate,
    int? runsPerWeekGoal,
  }) async {
    final existing = await getProgress(routeId);
    await saveProgress(UserRouteProgress(
      userId: userId,
      routeId: routeId,
      currentDistanceKm: existing?.currentDistanceKm ?? 0,
      targetEndDate: targetEndDate,
      runsPerWeekGoal: runsPerWeekGoal,
      isCompleted: existing?.isCompleted ?? false,
      startedAt: existing?.startedAt ?? DateTime.now(),
      completedAt: existing?.completedAt,
      clearedCheckpoints: existing?.clearedCheckpoints ?? const [],
    ));
  }
}
