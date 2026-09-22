import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/run_log.dart';
import '../models/user_route_progress.dart';
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

  /// ログイン中のユーザーについて、ローカル⇔クラウドの同期を1回実行する。
  /// 未ログイン時、または既に同期処理が進行中の場合は何もしない。
  Future<void> syncNow() async {
    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null || _syncing) return;

    _syncing = true;
    try {
      // 未ログイン時の初期シード・記録があれば現在のUIDに移行
      await _routeRepository.migrateFallbackUserIfNeeded(uid);
      await _pushLocalToCloud(uid);
      await _pullCloudToLocal(uid);
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
  Future<void> deleteCloudData(String uid) async {
    while (_syncing) {
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
  Future<void> _pullCloudToLocal(String uid) async {
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
      await _routeRepository.upsertRunLog(RunLog.fromMap(doc.data()));
    }
  }
}