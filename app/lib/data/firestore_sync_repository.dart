import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/run_log.dart';
import '../models/user_route_progress.dart';
import 'auth_repository.dart';
import 'route_repository.dart';

/// 端末内SQLite（[RouteRepository]）とクラウドのFirestoreとの同期処理。
///
/// 現段階では複数端末間の複雑な競合解決は行わず、シンプルな
/// 「ローカル→クラウドへpush → クラウド→ローカルへpull（後勝ち）」の
/// 一方向×2ステップで同期する。ドキュメントIDを安定させている
/// （routeIdやlogIdをそのままdocIdに使う）ため、同じレコードは
/// 常に同じドキュメントを上書きするだけで、重複は発生しない。
///
/// ログインしていない場合は何もしない（syncNowは即座に戻る）。
class FirestoreSyncRepository {
  FirestoreSyncRepository._();

  static final FirestoreSyncRepository instance = FirestoreSyncRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final RouteRepository _routeRepository = RouteRepository.instance;

  bool _syncing = false;

  /// ログイン中のユーザーについて、ローカル⇔クラウドの同期を1回実行する。
  /// 未ログイン時、または既に同期処理が進行中の場合は何もしない。
  ///
  /// オフライン時やFirestoreエラー時は、失敗を握りつぶして次回の同期に委ねる
  /// （PR #14レビュー指摘対応）。呼び出し元（UIの手動同期ボタンなど）を
  /// 例外で落とさないようにするため。
  Future<void> syncNow() async {
    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null || _syncing) return;

    _syncing = true;
    try {
      await _pushLocalToCloud(uid);
      await _pullCloudToLocal(uid);
    } catch (_) {
      // オフライン・権限エラーなどで失敗しても、ここでは何もしない。
      // 次回のsyncNow()呼び出しで再試行される。
    } finally {
      _syncing = false;
    }
  }

  CollectionReference<Map<String, dynamic>> _progressCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('progress');

  CollectionReference<Map<String, dynamic>> _runLogsCollection(String uid) =>
      _firestore.collection('users').doc(uid).collection('runLogs');

  /// ローカルSQLiteの内容をFirestoreへ書き込む。
  ///
  /// 複数端末で同期せずに使われた場合、単純に上書きすると後から同期した方が
  /// 先に同期された新しい進捗を消してしまう可能性がある（PR #14レビュー指摘）。
  /// そのため、クラウド側に既存のドキュメントがある場合はupdated_atを比較し、
  /// ローカルの方が新しい（またはクラウド側にまだ無い）場合のみ上書きする。
  /// run_logsは追記のみで更新されないレコードのため、従来どおり無条件でpushする。
  Future<void> _pushLocalToCloud(String uid) async {
    final progressList = await _routeRepository.getAllProgress();
    final runLogs = await _routeRepository.getRunLogs();
    if (progressList.isEmpty && runLogs.isEmpty) return;

    final batch = _firestore.batch();

    for (final progress in progressList) {
      final docRef = _progressCollection(uid).doc(progress.routeId);
      final existing = await docRef.get();
      if (existing.exists) {
        final existingUpdatedAtRaw = existing.data()?['updated_at'] as String?;
        final existingUpdatedAt =
            (existingUpdatedAtRaw != null && existingUpdatedAtRaw.isNotEmpty)
                ? DateTime.tryParse(existingUpdatedAtRaw)
                : null;
        if (existingUpdatedAt != null && existingUpdatedAt.isAfter(progress.updatedAt)) {
          // クラウド側の方が新しいので、このレコードはpushしない
          // （このあとの_pullCloudToLocalでローカルに取り込まれる）。
          continue;
        }
      }
      batch.set(docRef, progress.toMap());
    }

    for (final log in runLogs) {
      batch.set(_runLogsCollection(uid).doc(log.logId), log.toMap());
    }
    await batch.commit();
  }

  /// Firestore側の内容をローカルSQLiteへ反映する（ConflictAlgorithm.replaceで
  /// upsertするため、他端末で更新されたレコードもこの端末に取り込める）。
  Future<void> _pullCloudToLocal(String uid) async {
    final progressSnapshot = await _progressCollection(uid).get();
    for (final doc in progressSnapshot.docs) {
      await _routeRepository.saveProgress(UserRouteProgress.fromMap(doc.data()));
    }

    final runLogsSnapshot = await _runLogsCollection(uid).get();
    for (final doc in runLogsSnapshot.docs) {
      await _routeRepository.upsertRunLog(RunLog.fromMap(doc.data()));
    }
  }
}