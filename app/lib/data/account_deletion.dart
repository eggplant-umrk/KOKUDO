/// アカウント削除が最後まで進まなかった理由。
///
/// 削除は「クラウド削除 → 認証削除(必要なら再認証) → 端末内削除」の3段階で、
/// どこで止まったかによって利用者に伝えるべきことが変わる。文言は
/// widgets/settings_sheet.dart 側で組み立てる。
enum AccountDeletionFailure {
  /// 記録の同期が終わらず、クラウドの削除を始められなかった。
  /// 同期の途中で消すと、走っている同期が消した端から書き戻してしまうため、
  /// 待たずに進めるのではなく中断する。
  syncBusy,

  /// 本人確認(再認証)のアカウント選択を、利用者がキャンセルした。
  reauthCancelled,

  /// この環境では再認証のダイアログを出せない(Web版)。
  /// ログアウト→再ログインしてからやり直してもらう。
  reauthUnavailable,

  /// 再認証で、ログイン中のものとは別のGoogleアカウントが選ばれた。
  accountMismatch,

  /// 時間内に終わらなかった(通信不良など)。
  ///
  /// 中断はするが、裏で進んでいた処理はそのまま完了することがある
  /// (Firestoreの書き込みはオンラインに戻った時点で反映される)ため、
  /// 「失敗した」ではなく「完了していないかもしれない」と伝える。
  timedOut,
}

/// アカウント削除を中断した。[reason] に止まった理由を持つ。
class AccountDeletionException implements Exception {
  final AccountDeletionFailure reason;

  const AccountDeletionException(this.reason);

  @override
  String toString() => 'AccountDeletionException(${reason.name})';
}
