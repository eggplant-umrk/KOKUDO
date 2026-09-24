// 走行記録を削除したときに「消した」という控えが残り、同期が終わったら
// 片付けられることを確認する。
//
// この控えが無いと、同期は push のあとに pull をするので、ローカルで消した
// 記録がクラウドから戻ってくる。症状は「消したはずの記録が次のログインで
// 復活する」という形でしか出ず、例外も出ないので気づきにくい。
//
// Firestoreへの実際の書き込みはここでは行わず、端末内SQLiteの範囲だけを見る。
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kokudo/data/app_database.dart';
import 'package:kokudo/data/auth_repository.dart';
import 'package:kokudo/data/route_repository.dart';
import 'package:kokudo/models/run_log.dart';

/// テスト用の走行記録を1件作って保存する。
Future<RunLog> _addLog(RouteRepository repo, String logId) async {
  final log = RunLog(
    logId: logId,
    userId: RouteRepository.currentUserId,
    routeId: '1',
    distanceKm: 5,
    durationSeconds: 1800,
    caloriesBurned: 310,
    recordedAt: DateTime(2026, 9, 24),
  );
  await repo.addRunLog(log);
  return log;
}

void main() {
  // 素の test() なのでバインディングが張られておらず、そのままだと
  // RouteCatalog が rootBundle からアセットを読むところで
  // 「Binding has not yet been initialized」になる。明示的に初期化する。
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await AppDatabase.instance.resetForTesting();
    RouteRepository.instance.resetSeedCacheForTesting();

    // AuthRepository.instance は「読む前に書く」。先に読むと本物の
    // FirebaseAuth.instance を触りに行き、Firebase未初期化で落ちる
    // (widget_test.dart の注意1と同じ理由)。
    AuthRepository.instance = AuthRepository.forTesting(
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(uid: 'test-uid', email: 'test@example.com'),
      ),
    );
  });

  test('走行記録を削除すると、クラウドへ伝えるための控えが残る', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final log = await _addLog(repo, 'log_delete_1');

    expect(await repo.pendingRunLogDeletions(), isEmpty);

    await repo.deleteRunLog(log);

    final remaining = await repo.getRunLogs();
    expect(remaining.map((l) => l.logId), isNot(contains(log.logId)));
    expect(await repo.pendingRunLogDeletions(), contains(log.logId));
  });

  test('クラウドから消し終えた控えは片付けられる', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final log = await _addLog(repo, 'log_delete_2');

    await repo.deleteRunLog(log);
    await repo.clearRunLogDeletions([log.logId]);

    expect(await repo.pendingRunLogDeletions(), isEmpty);
  });

  test('片付けるのは渡したIDだけで、まだ消せていない分は残る', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final first = await _addLog(repo, 'log_delete_3');
    final second = await _addLog(repo, 'log_delete_4');

    await repo.deleteRunLog(first);
    await repo.deleteRunLog(second);
    await repo.clearRunLogDeletions([first.logId]);

    expect(await repo.pendingRunLogDeletions(), [second.logId]);
  });

  test('同じ記録を二度削除しても控えは1件のまま', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final log = await _addLog(repo, 'log_delete_5');

    await repo.deleteRunLog(log);
    await repo.deleteRunLog(log);

    expect(await repo.pendingRunLogDeletions(), [log.logId]);
  });

  // 同期中に削除すると記録が復活するバグの再現テスト。
  //
  // 同期の pull は「クラウドにまだ残っている記録をローカルへ取り込む
  // (upsertRunLog)」処理だが、その記録がちょうど端末側で削除され、
  // まだクラウドへ伝え切っていない(控えが残っている)場合は、取り込みで
  // 復活させてはいけない。
  test('削除待ちの記録は、同期中のクラウド取り込みでは復活しない', () async {
    final repo = RouteRepository.instance;
    await repo.ensureSeeded();
    final log = await _addLog(repo, 'log_delete_6');

    await repo.deleteRunLog(log);
    expect(await repo.pendingRunLogDeletions(), contains(log.logId));

    // 同期の pull が、クラウド側にまだ残っている同じ記録を取り込もうと
    // した状況を再現する(削除の控えがある間はスキップされるはず)。
    await repo.upsertRunLog(log);

    final remaining = await repo.getRunLogs();
    expect(remaining.map((l) => l.logId), isNot(contains(log.logId)));
    // 復活していないので、控えも引き続き残っている。
    expect(await repo.pendingRunLogDeletions(), contains(log.logId));
  });
}
