import 'dart:async';

import 'account_deletion.dart';
import 'auth_repository.dart';
import 'firestore_sync_repository.dart';
import 'route_repository.dart';

/// アカウント削除の手順をまとめたサービス(リリース前修正項目 2-2)。
///
/// 順番に意味がある:
/// 1. クラウドのデータを消す(認証が生きているうちでないとルールで拒否される)
/// 2. Firebase Authentication のユーザーを消す(必要なら再認証)
/// 3. 端末内の記録を消す
///
/// 2で止まった場合、クラウドだけが空で端末内の記録は残っている状態になる。
/// そのままだと次に同期が走るまでクラウドが空のままなので、その場で
/// 書き戻しの同期を投げてから中断する(=削除を途中でやめても記録は失われない)。
class AccountService {
  AccountService._();

  static final AccountService instance = AccountService._();

  /// 削除すると何が失われるかを数えて返す。確認ダイアログで具体的な数字を
  /// 見せるために使う(「本当に消していいか」を判断できるようにするため)。
  /// 端末内のDBを読むだけなので通信はしない。
  Future<AccountDataSummary> summarizeUserData() async {
    final counts = await RouteRepository.instance.countLocalRecords();
    return AccountDataSummary(
      runLogCount: counts.runLogCount,
      totalDistanceKm: counts.totalDistanceKm,
      completedRouteCount: counts.completedRouteCount,
    );
  }

  /// 削除全体の制限時間。
  ///
  /// 通信できないときに待ち続けないための保険。Firestoreの書き込みは
  /// オフラインだとオンラインに戻るまで完了しないので、これが無いと
  /// 「削除しています…」のまま戻れなくなる。
  /// 時間切れにしても裏の処理は止まらず、後から完了することがあるため、
  /// 利用者には「失敗した」ではなく「完了していないかもしれない」と伝える。
  static const Duration _deletionTimeout = Duration(seconds: 30);

  Future<void> deleteAccount() {
    return _deleteAccount().timeout(
      _deletionTimeout,
      onTimeout: () => throw const AccountDeletionException(AccountDeletionFailure.timedOut),
    );
  }

  Future<void> _deleteAccount() async {
    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null) return;

    await FirestoreSyncRepository.instance.deleteCloudData(uid);
    try {
      await AuthRepository.instance.deleteCurrentUser();
    } catch (_) {
      // 認証を消せなかった = まだログイン中。クラウドだけ空の状態なので、
      // 端末内の記録を書き戻してから中断する。書き戻し自体に失敗しても、
      // 次に同期が走ったときにもう一度試される。
      unawaited(FirestoreSyncRepository.instance.syncNow());
      rethrow;
    }
    await RouteRepository.instance.deleteUserData(uid);
  }
}

/// アカウント削除で失われる記録の量。
class AccountDataSummary {
  /// 走行記録(ラン)の件数。
  final int runLogCount;

  /// 走った距離の合計(km)。路線ごとの進捗の合計。
  final double totalDistanceKm;

  /// 完走した国道の数。
  final int completedRouteCount;

  const AccountDataSummary({
    required this.runLogCount,
    required this.totalDistanceKm,
    required this.completedRouteCount,
  });

  /// 消えて困るものが何も無い状態か。
  bool get isEmpty => runLogCount == 0 && completedRouteCount == 0 && totalDistanceKm <= 0;
}
