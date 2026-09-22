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
/// 2で再認証がキャンセルされた場合、クラウドのデータは既に消えているが
/// 端末内の記録は残っているので、次回の同期でクラウドに書き戻される
/// (=削除を途中でやめても記録は失われない)。
class AccountService {
  AccountService._();

  static final AccountService instance = AccountService._();

  /// 削除すると何が失われるかを数えて返す。確認ダイアログで具体的な数字を
  /// 見せるために使う(「本当に消していいか」を判断できるようにするため)。
  /// 端末内のDBを読むだけなので通信はしない。
  Future<AccountDataSummary> summarizeUserData() async {
    final repo = RouteRepository.instance;
    final runLogs = await repo.getRunLogs();
    final totalDistanceKm = await repo.cumulativeDistanceKm();
    final completedRouteCount = await repo.completedRouteCount();
    return AccountDataSummary(
      runLogCount: runLogs.length,
      totalDistanceKm: totalDistanceKm,
      completedRouteCount: completedRouteCount,
    );
  }

  Future<void> deleteAccount() async {
    final uid = AuthRepository.instance.currentUser?.uid;
    if (uid == null) return;

    await FirestoreSyncRepository.instance.deleteCloudData(uid);
    await AuthRepository.instance.deleteCurrentUser();
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
