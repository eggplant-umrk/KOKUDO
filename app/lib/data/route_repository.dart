import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

import '../models/national_route.dart';
import '../models/route_checkpoint.dart';
import '../models/run_log.dart';
import '../models/user_route_progress.dart';
import 'app_database.dart';
import 'auth_repository.dart';
import 'mock_data.dart' as seed;

/// [AppDatabase]（端末内SQLite）を実データソースとして扱うリポジトリ。
///
/// バックエンド未接続の現段階では、初回起動時のみ mock_data.dart の内容を
/// 初期データとしてDBへ書き込む（デモ用シード）。以降は画面からの読み書きは
/// すべてこのクラス経由でSQLiteに対して行われる。
class RouteRepository {
  RouteRepository._();

  static final RouteRepository instance = RouteRepository._();

  /// 未ログイン時（テストやオフライン初期化など）のフォールバック用ユーザーID。
  static const String fallbackUserId = 'usr_123';

  /// ログイン中のFirebase Authのuidを返す。
  /// 未ログイン時はフォールバックとして[fallbackUserId]を使用する。
  static String get currentUserId => AuthRepository.instance.currentUser?.uid ?? fallbackUserId;

  /// 既存コード互換用のゲッター。
  static String get userId => currentUserId;

  /// 初回ログイン時など、ローカルの[fallbackUserId]の進捗・ログを[newUid]に移行する。
  Future<void> migrateFallbackUserIfNeeded(String newUid) async {
    if (newUid == fallbackUserId) return;
    await ensureSeeded();
    final db = await _db;
    final existingNew = await db.query(
      'user_route_progress',
      where: 'user_id = ?',
      whereArgs: [newUid],
    );
    if (existingNew.isEmpty) {
      await db.update(
        'user_route_progress',
        {'user_id': newUid},
        where: 'user_id = ?',
        whereArgs: [fallbackUserId],
      );
      await db.update(
        'run_logs',
        {'user_id': newUid},
        where: 'user_id = ?',
        whereArgs: [fallbackUserId],
      );
    }
  }

  Future<Database> get _db async => AppDatabase.instance.database;

  Future<void>? _seedFuture;

  /// national_routes が空の場合のみ、mock_data.dart の内容をシードする。
  /// 複数箇所から同時に呼ばれても二重シードされないよう、Futureをキャッシュする。
  Future<void> ensureSeeded() {
    return _seedFuture ??= _seed();
  }

  @visibleForTesting
  void resetSeedCacheForTesting() {
    _seedFuture = null;
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

  /// Firestore同期用に、ユーザーの全進捗レコードを取得する（[_allProgress]の公開版）。
  Future<List<UserRouteProgress>> getAllProgress() => _allProgress();

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

  /// Firestoreからのプル同期用: 同じlog_idが既に存在する場合は上書きする
  /// （[addRunLog]と異なりConflictAlgorithm.replaceを使うため、再同期時に
  /// 重複エラーにならない）。
  Future<void> upsertRunLog(RunLog log) async {
    final db = await _db;
    await db.insert(
      'run_logs',
      log.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<RunLog>> getRunLogs() async {
    await ensureSeeded();
    final db = await _db;
    final rows = await db.query('run_logs', where: 'user_id = ?', whereArgs: [userId]);
    return rows.map(RunLog.fromMap).toList();
  }

  /// 既存の走行記録の距離・時間を更新する。差分距離を進捗(currentDistanceKm)に
  /// 加算し、完走状態を再評価する。
  Future<void> updateRunLog({
    required RunLog oldLog,
    required double distanceKm,
    required int durationSeconds,
    required double caloriesBurned,
  }) async {
    final db = await _db;
    final updatedLog = RunLog(
      logId: oldLog.logId,
      userId: oldLog.userId,
      routeId: oldLog.routeId,
      distanceKm: distanceKm,
      durationSeconds: durationSeconds,
      caloriesBurned: caloriesBurned,
      recordedAt: oldLog.recordedAt,
    );
    await db.update(
      'run_logs',
      updatedLog.toMap(),
      where: 'log_id = ?',
      whereArgs: [oldLog.logId],
    );

    final deltaKm = distanceKm - oldLog.distanceKm;
    if (deltaKm != 0) {
      await _adjustProgress(oldLog.routeId, deltaKm);
    }
  }

  /// 走行記録を削除する。対象路線の進捗からもその分の距離を差し引く。
  Future<void> deleteRunLog(RunLog log) async {
    final db = await _db;
    await db.delete('run_logs', where: 'log_id = ?', whereArgs: [log.logId]);
    await _adjustProgress(log.routeId, -log.distanceKm);
  }

  /// [routeId]の進捗(currentDistanceKm)に[deltaKm]を加算し、完走判定を
  /// 再評価する。編集・削除どちらも記録の増減として扱えるよう共通化したもの。
  Future<void> _adjustProgress(String routeId, double deltaKm) async {
    final existing = await getProgress(routeId);
    if (existing == null) return;

    final route = await getRoute(routeId);
    final rawDistance = existing.currentDistanceKm + deltaKm;
    final newDistance = rawDistance < 0 ? 0.0 : rawDistance;
    final isCompleted = route != null && route.totalDistanceKm > 0 && newDistance >= route.totalDistanceKm;

    await saveProgress(UserRouteProgress(
      userId: existing.userId,
      routeId: existing.routeId,
      currentDistanceKm: (isCompleted && route != null) ? route.totalDistanceKm : newDistance,
      targetEndDate: existing.targetEndDate,
      runsPerWeekGoal: existing.runsPerWeekGoal,
      isCompleted: isCompleted,
      startedAt: existing.startedAt,
      completedAt: isCompleted ? (existing.completedAt ?? DateTime.now()) : null,
      clearedCheckpoints: existing.clearedCheckpoints,
      updatedAt: DateTime.now(),
    ));
  }

  /// 今日を含む連続記録日数(ストリーク)を返す。
  /// 今日まだ走っていなくても、前日まで連続していれば継続中として扱う
  /// (「今日中に走ればストリークを維持できる」という一般的な挙動)。
  Future<int> currentStreakDays() async {
    final logs = await getRunLogs();
    if (logs.isEmpty) return 0;

    final ranDays = logs
        .map((l) => DateTime(l.recordedAt.year, l.recordedAt.month, l.recordedAt.day))
        .toSet();

    final today = DateTime.now();
    var cursor = DateTime(today.year, today.month, today.day);
    if (!ranDays.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!ranDays.contains(cursor)) return 0;
    }

    var streak = 0;
    while (ranDays.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
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

  static const String _activeRouteIdSettingKey = 'active_route_id';

  Future<String?> _getSetting(String key) async {
    final db = await _db;
    final rows = await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> _setSetting(String key, String value) async {
    final db = await _db;
    await db.insert(
      'app_settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// 現在「挑戦中」の路線IDを返す。
  /// 1. [setActiveRoute]でユーザーが明示的に選んだ路線があれば、それを優先する
  ///    (ただし既に完走済みになっていた場合は無視して2.以降にフォールバックする)
  /// 2. 進捗があり未完走の路線があればそれを使う(手動選択がまだ一度も
  ///    行われていない既存ユーザー向けの後方互換)
  /// 3. どちらも無ければ、シードデータの初期アクティブ路線にフォールバックする
  Future<String> getActiveRouteId() async {
    final overrideId = await _getSetting(_activeRouteIdSettingKey);
    if (overrideId != null) {
      final overrideProgress = await getProgress(overrideId);
      if (overrideProgress == null || !overrideProgress.isCompleted) {
        return overrideId;
      }
    }

    final all = await _allProgress();
    for (final progress in all) {
      if (!progress.isCompleted && progress.currentDistanceKm > 0) {
        return progress.routeId;
      }
    }
    return seed.activeRouteId;
  }

  /// 「挑戦する国道を変更」から呼ぶ: 指定した路線を明示的にアクティブにする。
  /// - 進捗レコードがまだ無い場合は、今日を起点にした目標日(90日後)で新規作成する
  /// - 進捗はあるがまだ0km(実質未着手)の場合も、目標日を今日起点に立て直す。
  ///   シードデータ等の古い目標日をそのまま使うと、切り替え直後なのに
  ///   「1日◯kmペース」の必要ペース表示が実態と合わない数字になってしまうため。
  /// - 既に走った実績がある(0kmより進んでいる)場合は、その計画をそのまま維持する
  ///   (既存の進捗があれば維持し、後で切り替えて戻せば続きから再開できる)。
  /// 最後に選択内容をapp_settingsに保存する。
  Future<void> setActiveRoute(String routeId) async {
    final existing = await getProgress(routeId);
    if (existing == null) {
      await saveProgress(UserRouteProgress(
        userId: userId,
        routeId: routeId,
        currentDistanceKm: 0,
        targetEndDate: DateTime.now().add(const Duration(days: 90)),
        startedAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    } else if (existing.currentDistanceKm <= 0 && !existing.isCompleted) {
      await saveProgress(UserRouteProgress(
        userId: existing.userId,
        routeId: existing.routeId,
        currentDistanceKm: 0,
        targetEndDate: DateTime.now().add(const Duration(days: 90)),
        runsPerWeekGoal: existing.runsPerWeekGoal,
        isCompleted: false,
        startedAt: DateTime.now(),
        completedAt: null,
        clearedCheckpoints: existing.clearedCheckpoints,
        updatedAt: DateTime.now(),
      ));
    }
    await _setSetting(_activeRouteIdSettingKey, routeId);
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
  ///
  /// 戻り値: この呼び出しで新たに完走した（未完走→完走に変わった）場合はtrue。
  /// 完走演出（エフェクト表示）を出すべきかどうかの判定に使う。
  Future<bool> recordRun({
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
    final wasCompleted = existing?.isCompleted ?? false;
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
      updatedAt: DateTime.now(),
    ));

    return isCompleted && !wasCompleted;
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
      updatedAt: DateTime.now(),
    ));
  }
}
