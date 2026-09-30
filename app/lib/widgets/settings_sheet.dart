import 'dart:async';

import 'package:flutter/material.dart';

import '../data/account_deletion.dart';
import '../data/account_service.dart';
import '../data/auth_repository.dart';
import '../screens/privacy_policy_screen.dart';
import '../theme/app_colors.dart';

/// ホーム画面の歯車ボタンから開く設定シート。
///
/// 「挑戦する国道を変更」「プライバシーポリシー」「ログアウト」
/// 「アカウントを削除」を置く。以前は HeroStage の中にあったが、
/// アカウント削除の確認・進行表示が加わって大きくなったので切り出した。
Future<void> showSettingsSheet(BuildContext context, {required VoidCallback onChangeRoute}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusLg)),
    ),
    builder: (sheetContext) => _SettingsSheet(parentContext: context, onChangeRoute: onChangeRoute),
  );
}

class _SettingsSheet extends StatelessWidget {
  /// シートを開いたホーム画面側の context。シートを閉じた後に画面を開いたり
  /// ダイアログを出したりするのに使う(シート自身の context は閉じると使えない)。
  final BuildContext parentContext;
  final VoidCallback onChangeRoute;

  const _SettingsSheet({required this.parentContext, required this.onChangeRoute});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '設定',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            leading: const Icon(Icons.alt_route, color: AppColors.textSecondary),
            title: const Text('挑戦する国道を変更', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.of(context).pop();
              onChangeRoute();
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.textSecondary),
            title: const Text('プライバシーポリシー', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(parentContext).push(
                MaterialPageRoute<void>(builder: (_) => const PrivacyPolicyScreen()),
              );
            },
          ),
          const Divider(height: 8, indent: 20, endIndent: 20, color: AppColors.borderSubtle),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.textSecondary),
            title: const Text('ログアウト', style: TextStyle(fontWeight: FontWeight.w700)),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(_signOut(parentContext));
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: AppColors.danger),
            title: const Text(
              'アカウントを削除',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.danger),
            ),
            subtitle: const Text(
              '走行記録もすべて消えます',
              style: TextStyle(fontSize: 11, color: AppColors.textTertiary),
            ),
            onTap: () {
              Navigator.of(context).pop();
              unawaited(_confirmAndDeleteAccount(parentContext));
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// ログアウトする。
///
/// 成功すると authStateChanges が null を流し、AuthGate がログイン画面へ
/// 戻すので、ここでは画面操作をしない。失敗したときだけ、黙って何も
/// 起きないままにならないよう理由を知らせる。
///
/// [context] はシートを閉じた後も生きている、ホーム画面側の context を渡す。
Future<void> _signOut(BuildContext context) async {
  // await の前に取っておく。ログアウトが成功するとホーム画面の context が
  // 消えるため、後から ScaffoldMessenger.of(context) を呼ぶと落ちる。
  final messenger = ScaffoldMessenger.of(context);
  try {
    await AuthRepository.instance.signOut();
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('ログアウトできませんでした。通信環境を確認して、もう一度お試しください。'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 6),
      ),
    );
  }
}

/// 確認ダイアログ(2段階) → 進行中ダイアログ → 削除、の流れ。
///
/// 1回目は「何が起きるか」、2回目は「実際に何件・何km失うか」を見せる。
/// 取り消せない操作なので、勢いでタップしたまま最後まで進んでしまわないよう
/// 2段階にしている。
///
/// [context] はシートを閉じた後も生きている、ホーム画面側の context を渡す。
Future<void> _confirmAndDeleteAccount(BuildContext context) async {
  final firstConfirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('アカウントを削除しますか?'),
      content: const Text(
        'アカウントと、これまでの走行記録・国道の進捗がすべて削除されます。この操作は取り消せません。\n\n'
        '本人確認のため、Googleアカウントの選択画面がもう一度出ることがあります。',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('キャンセル', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('次へ'),
        ),
      ],
    ),
  );
  if (firstConfirmed != true || !context.mounted) return;

  // 2回目の確認では、消える記録の量を具体的に見せる。端末内のDBを読むだけ
  // なので待たせないが、失敗しても削除自体は続けられるようにnullを許す。
  AccountDataSummary? summary;
  try {
    summary = await AccountService.instance.summarizeUserData();
  } catch (_) {
    summary = null;
  }
  if (!context.mounted) return;

  final secondConfirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: const Text('本当に削除していいですか?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_deletionSummaryText(summary)),
          const SizedBox(height: 12),
          const Text(
            '削除すると元に戻せません。同じGoogleアカウントで入り直しても、これまでの記録は復元できません。',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.danger),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('やめておく', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(
            'すべて削除する',
            style: TextStyle(color: AppColors.danger),
          ),
        ),
      ],
    ),
  );
  if (secondConfirmed != true || !context.mounted) return;

  // 削除中は操作できないように、閉じられないダイアログを出しておく。
  //
  // ダイアログはアプリ最上位の Navigator に積まれるので、削除が成功して
  // AuthGate がログイン画面に切り替わっても勝手には消えない(ホーム画面の
  // context は消えるが、ダイアログは残る)。そのため Navigator と
  // ScaffoldMessenger は await の前に取っておき、成否にかかわらず自分で閉じる。
  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.routeSignBlue),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('アカウントを削除しています…')),
          ],
        ),
      ),
    ),
  ));

  String? errorMessage;
  try {
    await AccountService.instance.deleteAccount();
  } on AccountDeletionException catch (e) {
    errorMessage = _deletionFailureMessage(e.reason);
  } catch (_) {
    errorMessage = 'アカウントの削除に失敗しました。通信環境を確認して、もう一度お試しください。';
  }

  if (rootNavigator.mounted && rootNavigator.canPop()) rootNavigator.pop();
  // 成功したときも黙って画面が変わるだけにならないよう、必ず結果を知らせる。
  messenger.showSnackBar(
    SnackBar(
      content: Text(errorMessage ?? 'アカウントを削除しました。'),
      behavior: SnackBarBehavior.floating,
      duration: Duration(seconds: errorMessage == null ? 3 : 6),
    ),
  );
}

/// 削除が途中で止まったときに出す文面。
String _deletionFailureMessage(AccountDeletionFailure reason) {
  switch (reason) {
    case AccountDeletionFailure.syncBusy:
      return '記録の同期中です。少し待ってから、もう一度お試しください。';
    case AccountDeletionFailure.reauthCancelled:
      return 'アカウントの削除をキャンセルしました。';
    case AccountDeletionFailure.reauthUnavailable:
      return '本人確認のため、一度ログアウトしてから再度ログインし、もう一度お試しください。';
    case AccountDeletionFailure.accountMismatch:
      return 'ログイン中のものとは別のGoogleアカウントが選択されました。同じアカウントを選んでください。';
    case AccountDeletionFailure.timedOut:
      return '時間内に完了しませんでした。削除が済んでいない可能性があります。'
          '通信できる場所で、もう一度お試しください。';
  }
}

/// 2回目の確認ダイアログに出す「何が消えるか」の文面。
String _deletionSummaryText(AccountDataSummary? summary) {
  if (summary == null) {
    return 'これまでの走行記録・国道の進捗が、端末とクラウドの両方からすべて消えます。';
  }
  if (summary.isEmpty) {
    return 'まだ走行記録はありませんが、アカウントと設定はすべて消えます。';
  }
  final lines = <String>['次の記録が、端末とクラウドの両方からすべて消えます。', ''];
  if (summary.runLogCount > 0) lines.add('・走行記録 ${summary.runLogCount}件');
  if (summary.totalDistanceKm > 0) {
    lines.add('・走った距離 ${summary.totalDistanceKm.toStringAsFixed(1)}km');
  }
  if (summary.completedRouteCount > 0) {
    lines.add('・完走した国道 ${summary.completedRouteCount}路線');
  }
  return lines.join('\n');
}
