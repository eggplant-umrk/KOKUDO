// KokudoRunApp のスモークテスト。
//
// アプリが例外なく起動できること、およびホーム画面の主要な要素が
// 表示されていることを確認する。
//
// KokudoRunApp は AuthGate 経由で FirebaseAuth.instance のログイン状態を
// 購読するため、実際のFirebaseプロジェクトに接続せずにテストできるよう、
// setUp内で AuthRepository.instance を firebase_auth_mocks の
// MockFirebaseAuth に差し替えたテスト専用インスタンスへ置き換えている
// （PR #13レビュー指摘対応）。
//
// 注意1: AuthRepository.instance は「初回読み取り時に初期化される」静的
// フィールドで、初期化時に本物の FirebaseAuth.instance へアクセスしに行く
// （Firebase.initializeApp()未呼び出しのテスト環境では [core/no-app] で
// 落ちる）。そのため、このフィールドは setUp内で一度も読み取らず、必ず
// 先に書き込む（Dartの遅延初期化は「読む前に書けば初期化子は実行されない」
// 仕様のため）。「元のインスタンスを保存してtearDownで戻す」実装にすると、
// その保存のための読み取りで初期化子が走ってクラッシュするので行わない。
//
// 注意2: MockFirebaseAuth の authStateChanges() は、コンストラクタで
// signedIn: true を渡しても最初のイベントを発行しない（currentUserだけが
// 同期的に設定される）。そのためAuthGate側（app.dart）で
// StreamBuilder(initialData: AuthRepository.instance.currentUser, ...)
// として、ストリームの最初のイベントを待たずcurrentUserで初期分岐できるように
// してある。これが無いと、テストではAuthGateがローディング表示のまま
// 永久に進まなくなる。
//
// 注意3: RouteRepository.instance / AppDatabase.instance はどちらも
// プロセス全体で使い回されるシングルトンで、開いたDB接続やシード済み
// Futureをキャッシュしている。このファイルには testWidgets が複数あり、
// 1つ目のテストで開いた接続・シードキャッシュを2つ目のテストがそのまま
// 使い回すと、2つ目のテストのDBクエリが（例外も出さずに）二度と解決しない
// 状態になることを確認した。そのため setUp のたびに一度DB接続を閉じて
// キャッシュを空にし、各テストが必ず「まっさらな状態からDBを開き直す」
// ようにしている。
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kokudo/app.dart';
import 'package:kokudo/data/app_database.dart';
import 'package:kokudo/data/auth_repository.dart';
import 'package:kokudo/data/route_repository.dart';

void main() {
  // HomeScreenの初期化でRouteRepository経由のSQLite読み書きが走るが、
  // `flutter test`はVM上で動くためsqfliteのプラットフォームチャンネル実装が
  // 使えない（databaseFactory not initializedで落ちる）。FFI版に差し替える。
  //
  // ここで使うのは databaseFactoryFfi ではなく databaseFactoryFfiNoIsolate。
  // 通常のdatabaseFactoryFfiは内部でワーカーIsolateを使うが、widget test環境
  // ではそのIsolateとのやり取りがうまく完了しないことがあるため。
  // 参考: https://github.com/tekartik/sqflite/blob/master/sqflite_common_ffi/doc/testing.md
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    // 前のテストが開いたDB接続・シードキャッシュを必ず破棄してから、
    // 各テストがまっさらな状態でDBを開き直せるようにする（注意3参照）。
    await AppDatabase.instance.resetForTesting();
    RouteRepository.instance.resetSeedCacheForTesting();

    AuthRepository.instance = AuthRepository.forTesting(
      auth: MockFirebaseAuth(
        signedIn: true,
        mockUser: MockUser(
          uid: 'test-uid',
          email: 'test@example.com',
          displayName: 'テストユーザー',
        ),
      ),
    );
  });

  testWidgets('KokudoRunApp launches without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const KokudoRunApp());
    await _pumpUntilSettled(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home screen shows the start running button', (WidgetTester tester) async {
    await tester.pumpWidget(const KokudoRunApp());
    await _pumpUntilSettled(tester, maxPumps: 40);

    expect(find.text('ランニング開始'), findsOneWidget);
  });
}

/// HomeScreenのinitStateが行うSQLiteへの複数回の非同期読み書き
/// （RouteRepository経由、sqflite_common_ffi）が完了するまでフレームを
/// 送り続ける。
///
/// databaseFactoryFfiNoIsolateに変えてもなお、widget test環境内では
/// 時間を進めるだけの`pump()`だけではDB操作の完了が反映されないことが
/// あったため、`runAsync()`で実時間の隙間を挟んでから`pump()`する、を
/// 繰り返す方式にしている（plain testの中で直接呼ぶ分には問題なく完了する
/// ことは確認済みなので、widget test特有の事情と見られる）。
///
/// HeroStageの背景・キャラクターはループ再生するアニメーション画像なので、
/// `pumpAndSettle()`（フレームが尽きるまで待つ方式）は使えない（永久に終わらず
/// タイムアウトしてしまう）。そのため、固定回数のループにしている。
Future<void> _pumpUntilSettled(
  WidgetTester tester, {
  int maxPumps = 40,
  Duration delay = const Duration(milliseconds: 50),
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.runAsync(() => Future<void>.delayed(delay));
    await tester.pump();
  }
}