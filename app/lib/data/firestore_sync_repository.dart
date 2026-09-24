import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/run_log.dart';
import '../models/user_route_progress.dart';
import 'account_deletion.dart';
import 'auth_repository.dart';
import 'route_repository.dart';

/// 端末内SQLite（[RouteRepository]）とクラウドのFirestoreとの同期処理。
///
/// ドキュメントIDを安定させている（routeIdやlogIdをそのままdocIdに使う）ため、
/// 同じレコードは常に同じドキュメントを上書きするだけで重複は発生しない。
/// ログインしていない場合は何もしない（syncNowは即座に戻る）。
class FirestoreSyncRepository {
  FirestoreSyncRepository._();

  static final FirestoreSyncRepository instance = FirestoreSyncRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RouteRepository _routeRepository = RouteRepository.instance;

  bool _syncing = false;

  /// アカウント削除のとき、進行中の同期の終了を待つ上限。
  static const Duration _syncWaitLimit = Duration(seconds: 5);

  /// ログイン中のユーザーについて、ローカル⇔クラウドの同期を1回実行する。
  /// 未ログイン時、または既に同期処理が進行中の場合は何もしない。
  Future<void> syncNow() async {
    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null || _syncing) return;

    _syncing = true;
    try {
      // 未ログイン時の初期シード・記録があれば現在のUIDに移行
      await _routeRepository.migrateFallbackUserIfNeeded(uid);
      // 削除をいちばん先にクラウドへ伝える。あとの pull で消した記録が
      // 戻ってこないようにするため。
      final deletedLogIds = await _pushDeletionsToCloud(uid);
      await _pushLocalToCloud(uid);
      await _pullCloudToLocal(uid, skipRunLogIds: deletedLogIds);
    } catch (e, stackTrace) {
      debugPrint('FirestoreSyncRepository.syncNow error: $e\n$stackTrace');
    } finally {
      _syncing = false;
    }
  }

  CollectionReference<Map<String, dynamic>> _progressCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('progress');

  CollectionReference<Map<String, dynamic>> _runLogsCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('runLogs');

  /// 500件制限を安全に超えないよう、バッチをチャンク分割してcommitするヘルパー
  Future<void> _commitInBatches(
    List<void Function(WriteBatch batch)> operations,
  ) async {
    const chunkSize = 450;
    for (var i = 0; i < operations.length; i += chunkSize) {
      final batch = _firestore.batch();
      final end = (i + chunkSize < operations.length) ? i + chunkSize : operations.length;
      for (var j = i; j < end; j++) {
        operations[j](batch);
      }
      await batch.commit();
    }
  }

  /// アカウント削除時に、[uid] のクラウド上のデータ(進捗・走行ログ・
  /// ユーザードキュメント)をすべて消す。
  ///
  /// 認証が消える前(Firebase Authのユーザー削除より前)に呼ぶ必要がある。
  /// ユーザー削除後はセキュリティルールで本人のデータに触れなくなるため。
  /// 同期の途中で消すと消した端から書き戻されるので、同期中は待つ。
  /// ただし待ちっぱなしにはしない。オフラインだと Firestore の
  /// batch.commit() はオンラインに戻るまで完了しないため、走っている同期が
  /// いつまでも終わらないことがある。[_syncWaitLimit] を過ぎたら
  /// syncBusy として中断する(待たずに削除に進むと、その同期の push が
  /// 消したドキュメントを書き戻して、認証だけ消えたデータがクラウドに
  /// 取り残されてしまう)。
  Future<void> deleteCloudData(String uid) async {
    final deadline = DateTime.now().add(_syncWaitLimit);
    while (_syncing) {
      if (!DateTime.now().isBefore(deadline)) {
        throw const AccountDeletionException(AccountDeletionFailure.syncBusy);
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    _syncing = true;
    try {
      final operations = <void Function(WriteBatch batch)>[];
      for (final collection in [_progressCollection(uid), _runLogsCollection(uid)]) {
        final snapshot = await collection.get();
        for (final doc in snapshot.docs) {
          operations.add((batch) => batch.delete(doc.reference));
        }
      }
      operations.add((batch) => batch.delete(_firestore.collection('users').doc(uid)));
      await _commitInBatches(operations);
    } finally {
      _syncing = false;
    }
  }

  /// ローカルで削除された走行記録を、クラウド側からも消す。
  ///
  /// 消し終えた控えは片付ける。commitに失敗した場合は控えを残したまま
  /// 例外が上がり、[syncNow] が同期ごと中断するので、次の同期でやり直す。
  /// 戻り値は今回消したlogIdで、続く pull で弾くのに使う(削除が反映される
  /// 前のスナップショットを読んでしまった場合の保険)。
  Future<Set<String>> _pushDeletionsToCloud(String uid) async {
    final logIds = await _routeRepository.pendingRunLogDeletions();
    if (logIds.isEmpty) return const <String>{};

    final operations = <void Function(WriteBatch batch)>[
      for (final logId in logIds)
        (batch) => batch.delete(_runLogsCollection(uid).doc(logId)),
    ];
    await _commitInBatches(operations);
    await _routeRepository.clearRunLogDeletions(logIds);
    return logIds.toSet();
  }

  /// ローカルSQLiteの内容をFirestoreへ書き込む。
  ///
  /// N+1クエリを防ぐため、コレクション全体を1回のget()で取得してメモリ上で比較する。
  /// クラウド側に既存のドキュメントがある場合はupdated_atを比較し、
  /// ローカルの方が新しい（またはクラウド側にまだ無い）場合のみ上書きする。
  Future<void> _pushLocalToCloud(String uid) async {
    final progressList = await _routeRepository.getAllProgress();
    final runLogs = await _routeRepository.getRunLogs();
    if (progressList.isEmpty && runLogs.isEmpty) return;

    // クラウド側の進捗を1回で取得してマップ化 (N+1クエリ解消)
    final cloudProgressSnapshot = await _progressCollection(uid).get();
    final cloudProgressMap = {
      for (final doc in cloudProgressSnapshot.docs) doc.id: doc.data(),
    };

    final operations = <void Function(WriteBatch batch)>[];

    for (final progress in progressList) {
      final cloudData = cloudProgressMap[progress.routeId];
      if (cloudData != null) {
        final existingUpdatedAtRaw = cloudData['updated_at'] as String?;
        final existingUpdatedAt =
            (existingUpdatedAtRaw != null && existingUpdatedAtRaw.isNotEmpty)
                ? DateTime.tryParse(existingUpdatedAtRaw)
                : null;
        if (existingUpdatedAt != null && existingUpdatedAt.isAfter(progress.updatedAt)) {
          // クラウド側の方が新しいのでpushしない（pullでローカルに取り込む）
          continue;
        }
      }
      final docRef = _progressCollection(uid).doc(progress.routeId);
      operations.add((batch) {
        batch.set(docRef, progress.toMap());
      });
    }

    for (final log in runLogs) {
      final docRef = _runLogsCollection(uid).doc(log.logId);
      operations.add((batch) {
        batch.set(docRef, log.toMap());
      });
    }

    await _commitInBatches(operations);
  }

  /// Firestore側の内容をローカルSQLiteへ反映する。
  /// クラウド側のデータで無条件に上書きせず、ローカルのupdatedAtと比較してから取り込む。
  Future<void> _pullCloudToLocal(String uid, {Set<String> skipRunLogIds = const <String>{}}) async {
    final progressSnapshot = await _progressCollection(uid).get();
    final localProgressList = await _routeRepository.getAllProgress();
    final localProgressMap = {for (final p in localProgressList) p.routeId: p};

    for (final doc in progressSnapshot.docs) {
      final cloudProgress = UserRouteProgress.fromMap(doc.data());
      final localProgress = localProgressMap[cloudProgress.routeId];
      // ローカルが存在し、ローカルの方が新しい場合は上書きしない
      if (localProgress != null && localProgress.updatedAt.isAfter(cloudProgress.updatedAt)) {
        continue;
      }
      await _routeRepository.saveProgress(cloudProgress);
    }

    final runLogsSnapshot = await _runLogsCollection(uid).get();
    for (final doc in runLogsSnapshot.docs) {
      // 今しがた消したばかりの記録は取り込まない。
      if (skipRunLogIds.contains(doc.id)) continue;
      await _routeRepository.upsertRunLog(RunLog.fromMap(doc.data()));
    }
  }
}