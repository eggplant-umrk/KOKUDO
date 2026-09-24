import 'package:meta/meta.dart';
import 'package:sqflite/sqflite.dart';

import '../models/national_route.dart';
import '../models/route_checkpoint.dart';
import '../models/run_log.dart';
import '../models/user_route_progress.dart';
import 'app_database.dart';
import 'auth_repository.dart';
import 'route_catalog.dart';

/// [AppDatabase]（端末内SQLite）を実データソースとして扱うリポジトリ。
///
/// 国道のマスターデータ(全459路線)は同梱の `assets/routes/national_routes.json`
/// ([RouteCatalog])を正とし、起動時にDBへ流し込む(JSONの version が上がったら
/// 入れ直す)。バックエンド未接続の現段階では、進捗・走行ログが1件も無い初回起動時
/// 進捗・走行ログはすべてユーザー自身の操作から作られる(デモデータの初期投入は
/// リリース前修正項目 1-1 で取り除いた)。画面からの読み書きはすべてこのクラス
/// 経由でSQLiteに対して行われる。
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
      await db.update(
        'deleted_run_logs',
        {'user_id': newUid},
        where: 'user_id = ?',
        whereArgs: [fallbackUserId],
      );
    }
  }

  Future<Database> get _db async => AppDatabase.instance.database;

  /// 端末内に残っている、この端末の利用者の記録の量。
  /// アカウント削除の確認画面で「何が消えるか」を見せるために使う。
  ///
  /// [deleteUserData] が消す範囲と揃えるため、user_id では絞らない。
  /// ログイン直後の同期([migrateFallbackUserIfNeeded])が失敗していると
  /// 記録が [fallbackUserId] のまま残っていることがあり、uidで絞ると
  /// 「消えるものはありません」と出したうえで実際には消してしまうため。
  Future<({int runLogCount, double totalDistanceKm, int completedRouteCount})>
      countLocalRecords() async {
    await ensureSeeded();
    final db = await _db;
    final runLogCount =
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM run_logs')) ?? 0;
    final progressRows = await db.query('user_route_progress');
    final progress = progressRows.map(UserRouteProgress.fromMap).toList();
    return (
      runLogCount: runLogCount,
      totalDistanceKm: progress.fold<double>(0, (sum, p) => sum + p.currentDistanceKm),
      completedRouteCount: progress.where((p) => p.isCompleted).length,
    );
  }

  /// アカウント削除時に、[uid] の進捗・走行ログと、路線の選択などの設定を
  /// 端末から消す。路線マスター(national_routes / route_checkpoints)は
  /// ユーザーのデータではないので残す。
  Future<void> deleteUserData(String uid) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('user_route_progress', where: 'user_id = ?', whereArgs: [uid]);
      await txn.delete('run_logs', where: 'user_id = ?', whereArgs: [uid]);
      // フォールバックIDのまま残っている未ログイン時の記録も、この端末の
      // 利用者のものなので一緒に消す。
      await txn.delete('user_route_progress', where: 'user_id = ?', whereArgs: [fallbackUserId]);
      await txn.delete('run_logs', where: 'user_id = ?', whereArgs: [fallbackUserId]);
      // 削除の控えも消す。アカウントごと消すので、クラウドへ伝える相手が
      // もう居ない(クラウド側は deleteCloudData がまとめて消している)。
      await txn.delete('deleted_run_logs', where: 'user_id = ?', whereArgs: [uid]);
      await txn.delete('deleted_run_logs', where: 'user_id = ?', whereArgs: [fallbackUserId]);
      await txn.delete('app_settings', where: 'key = ?', whereArgs: [_activeRouteIdSettingKey]);
    });
  }

  Future<void>? _seedFuture;

  /// 路線マスターをDBに同期し、進捗・ログが空ならデモデータをシードする。
  /// 複数箇所から同時に呼ばれても二重に走らないよう、Futureをキャッシュする。
  /// 失敗したときはキャッシュを捨てて、次の呼び出しでやり直せるようにする
  /// (失敗したFutureを持ち続けると、以降のすべての読み込みが同じエラーになる)。
  Future<void> ensureSeeded() {
    final future = _seedFuture ??= _seed();
    return future.catchError((Object error, StackTrace stackTrace) {
      if (identical(_seedFuture, future)) _seedFuture = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  @visibleForTesting
  void resetSeedCacheForTesting() {
    _seedFuture = null;
  }

  Future<void> _seed() async {
    final db = await _db;
    await _syncRouteCatalog(db);
  }

  /// DBに入れた路線マスターの版。JSON側の `version` と比べて入れ直しを判断する。
  static const String _routeCatalogVersionSettingKey = 'route_catalog_version';

  /// [RouteCatalog](同梱JSON)の内容を national_routes / route_checkpoints に流し込む。
  ///
  /// 同梱JSONの version がDBに記録した版と同じで、路線も入っていれば何もしない。
  /// 版が上がっていれば(距離を実延長に差し替えたときなど)全路線を入れ直す。
  /// 路線IDは変えないので、user_route_progress / run_logs はそのまま生きる。
  /// 旧版(先行6路線だけをDBに入れていた端末)からの移行もこの処理で済む。
  /// 完走済みの進捗は新しい総距離に合わせて距離を揃える(距離が変わって
  /// 「完走なのに93%」にならないように)。
  ///
  /// JSONが読めない場合、路線が既にDBにあればそのまま続行し、無ければ例外にする
  /// (路線ゼロで起動しても何もできないため)。
  Future<void> _syncRouteCatalog(Database db) async {
    final count = Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM national_routes'),
        ) ??
        0;
    final int version;
    final List<NationalRoute> routes;
    try {
      version = await RouteCatalog.version();
      final storedVersion = int.tryParse(await _getSetting(_routeCatalogVersionSettingKey) ?? '');
      if (storedVersion == version && count > 0) return;
      routes = await RouteCatalog.load();
    } catch (_) {
      if (count > 0) return;
      rethrow;
    }
    if (routes.isEmpty) {
      if (count > 0) return;
      throw StateError('路線マスター(${RouteCatalog.assetPath})が空です');
    }

    await db.transaction((txn) async {
      final batch = txn.batch();
      // 版が変わったら全部入れ直す(JSONから消えた路線を残さないため)。
      batch.delete('route_checkpoints');
      batch.delete('national_routes');
      for (final route in routes) {
        batch.insert('national_routes', route.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        for (final checkpoint in route.checkpoints) {
          batch.insert('route_checkpoints', checkpoint.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
      // 完走済みは新しい総距離に、未完走は総距離を超えないように揃える。
      batch.rawUpdate('''
        UPDATE user_route_progress
        SET current_distance_km = (
          SELECT total_distance_km FROM national_routes n WHERE n.route_id = user_route_progress.route_id
        )
        WHERE is_completed = 1
          AND route_id IN (SELECT route_id FROM national_routes)
      ''');
      batch.rawUpdate('''
        UPDATE user_route_progress
        SET current_distance_km = (
          SELECT total_distance_km FROM national_routes n WHERE n.route_id = user_route_progress.route_id
        )
        WHERE is_completed = 0
          AND current_distance_km > (
            SELECT total_distance_km FROM national_routes n WHERE n.route_id = user_route_progress.route_id
          )
      ''');
      batch.insert(
        'app_settings',
        {'key': _routeCatalogVersionSettingKey, 'value': '$version'},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await batch.commit(noResult: true);
    });
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

  /// ユーザーの全進捗を routeId をキーにしたMapで返す。
  /// 一覧画面で路線ごとに [getProgress] を呼ぶと459回のクエリになるため、
  /// まとめて1回で取るためのもの。
  Future<Map<String, UserRouteProgress>> getProgressByRoute() async {
    final all = await _allProgress();
    return {for (final progress in all) progress.routeId: progress};
  }

  /// 進捗レコードから路線のステータスを判定する([routeStatusOf] と同じ規則)。
  /// 一度にチャレンジできるのは1路線のみのため、進捗が付いていても
  /// currentDistanceKm が0より大きい路線だけを「挑戦中」とみなす。
  static RouteStatus statusOfProgress(UserRouteProgress? progress) {
    if (progress == null) return RouteStatus.notStarted;
    if (progress.isCompleted) return RouteStatus.completed;
    if (progress.currentDistanceKm > 0) return RouteStatus.inProgress;
    return RouteStatus.notStarted;
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

  /// Firestoreからのプル同期用: 同じlog_idが既に存在する場合は上書きする
  /// （[addRunLog]と異なりConflictAlgorithm.replaceを使うため、再同期時に
  /// 重複エラーにならない）。
  /// クラウドから取り込んだ走行記録をローカルへ反映する。
  ///
  /// この記録がちょうど端末側で削除された(または削除の途中で)場合に
  /// 復活してしまわないよう、delete_run_logs への挿入([deleteRunLog])と
  /// 同じテーブルへの読み書きを1つのトランザクションにまとめている。
  /// sqfliteは同一DBへのトランザクションを直列に実行するため、
  /// [deleteRunLog] と本メソッドがほぼ同時に呼ばれても、どちらが先に
  /// コミットされたかで結果が一意に決まる(削除が先ならここでスキップし、
  /// 取り込みが先でも直後の削除がrun_logsから消して控えを残すので、
  /// 呼び出し順に関わらず最終的に「削除済み」の状態に収束する)。
  Future<void> upsertRunLog(RunLog log) async {
    final db = await _db;
    await db.transaction((txn) async {
      final pendingDeletion = await txn.query(
        'deleted_run_logs',
        columns: ['log_id'],
        where: 'log_id = ? AND user_id IN (?, ?)',
        whereArgs: [log.logId, currentUserId, fallbackUserId],
        limit: 1,
      );
      if (pendingDeletion.isNotEmpty) return;
      await txn.insert(
        'run_logs',
        log.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
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
  ///
  /// 「消した」という控えを deleted_run_logs に残す。これが無いと、次の
  /// 同期の pull でクラウドに残っている同じ記録がローカルへ戻ってくる。
  Future<void> deleteRunLog(RunLog log) async {
    final db = await _db;
    await db.transaction((txn) async {
      await txn.delete('run_logs', where: 'log_id = ?', whereArgs: [log.logId]);
      await txn.insert(
        'deleted_run_logs',
        {
          'log_id': log.logId,
          'user_id': currentUserId,
          'deleted_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
    await _adjustProgress(log.routeId, -log.distanceKm);
  }

  /// まだクラウドへ伝えていない「削除した走行記録」のID。
  ///
  /// ログイン前に消した記録は [fallbackUserId] のまま残っていることが
  /// あるので、そちらも拾う(ログイン時の移行が失敗していても取りこぼさない)。
  Future<List<String>> pendingRunLogDeletions() async {
    final db = await _db;
    final rows = await db.query(
      'deleted_run_logs',
      columns: ['log_id'],
      where: 'user_id IN (?, ?)',
      whereArgs: [currentUserId, fallbackUserId],
    );
    return rows.map((row) => row['log_id'] as String).toList();
  }

  /// クラウドから消し終えた控えを片付ける。
  /// 消せなかった分は残しておき、次の同期でもう一度試す。
  Future<void> clearRunLogDeletions(Iterable<String> logIds) async {
    final ids = logIds.toList();
    if (ids.isEmpty) return;
    final db = await _db;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete('deleted_run_logs', where: 'log_id IN ($placeholders)', whereArgs: ids);
  }

  /// [routeId]の進捗(currentDistanceKm)に[deltaKm]を加算し、完走判定を
  /// 再評価する。編集・削除どちらも記録の増減として扱えるよう共通化したもの。
  Future<void> _adjustProgress(String routeId, double deltaKm) async {
    final existing = await getProgress(routeId);
    if (existing == null) return;

    final route = await getRoute(routeId);
    final rawDistance = existing.currentDistanceKm + deltaKm;
    final newDistance = rawDistance < 0 ? 0.0 : rawDistance;
    final totalKm = route?.totalDistanceKm ?? 0;
    final isCompleted = totalKm > 0 && newDistance >= totalKm;

    await saveProgress(UserRouteProgress(
      userId: existing.userId,
      routeId: existing.routeId,
      currentDistanceKm: isCompleted ? totalKm : newDistance,
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

  /// 1路線のステータスを返す。判定規則は [statusOfProgress] を参照。
  Future<RouteStatus> routeStatusOf(String routeId) async {
    return statusOfProgress(await getProgress(routeId));
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

  /// 現在「挑戦中」の路線IDを返す。まだ決まっていなければ null。
  /// 1. [setActiveRoute]でユーザーが明示的に選んだ路線があれば、それを優先する
  ///    (ただし既に完走済みになっていた場合は無視して2.以降にフォールバックする)
  /// 2. 進捗があり未完走の路線があればそれを使う(手動選択がまだ一度も
  ///    行われていない既存ユーザー向けの後方互換)
  /// 3. どちらも無ければ null を返す。初回起動のほか、挑戦していた路線を
  ///    完走した直後もここに来る。呼び出し側で「次に挑戦する国道を選ぶ」
  ///    画面へ促すこと。
  Future<String?> getActiveRouteId() async {
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
    return null;
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

  /// 全国道の総延長の合計(km)。カバー率の分母。
  Future<double> nationalNetworkTotalKm() async {
    await ensureSeeded();
    final db = await _db;
    final rows = await db.rawQuery('SELECT SUM(total_distance_km) AS total FROM national_routes');
    return (rows.first['total'] as num?)?.toDouble() ?? 0;
  }

  Future<double> coverageRatio() async {
    final cumulative = await cumulativeDistanceKm();
    final total = await nationalNetworkTotalKm();
    if (total <= 0) return 0;
    final ratio = cumulative / total;
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
