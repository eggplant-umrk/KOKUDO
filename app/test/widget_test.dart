// KokudoRunApp のスモークテスト。
//
// アプリが例外なく起動できること、およびホーム画面の主要な要素が
// 表示されていることを確認する。
//
// KokudoRunApp は AuthGate 経由で FirebaseAuth.instance のログイン状態を
// 購読するため、実際のFirebaseプロジェクトに接続せずにテストできるよう、
// setUp内で AuthRepository.instance を firebase_auth_mocks の
// MockFirebaseAuth に差し替えたテスト専用インスタンスへ置き換えている
// (PR #13レビュー指摘対応)。
//
// 注意1: AuthRepository.instance は「初回読み取り時に初期化される」遅延
// フィールドで、初期化時に本物の FirebaseAuth.instance へアクセスしに行く
// (Firebase.initializeApp()未呼び出しのテスト環境では [core/no-app] で
// 落ちる)。そのため、このフィールドは setUp内で一度も読み取らず、必ず
// 先に書き込む(Dartの遅延初期化は「読む前に書けば初期化子は実行されない」
// 仕様のため)。
//
// 注意2: MockFirebaseAuth の authStateChanges() は、コンストラクタで
// signedIn: true を渡しても最初のイベントを発行しない(currentUserだけが
// 同期的に設定される)。そのためAuthGate側(app.dart)で
// StreamBuilder(initialData: AuthRepository.instance.currentUser, ...)
// として、ストリームの最初のイベントを待たずcurrentUserで初期分岐できるように
// してある。これが無いと、テストではAuthGateがローディング表示のまま
// 進まなくなる。
//
// 注意3: RouteRepository.instance / AppDatabase.instance はどちらも
// プロセス全体で使い回されるシングルトンで、開いたDB接続やシード済み
// キャッシュを保持している。このファイルには testWidgets が複数あり、
// 前のテストが開いた接続・キャッシュを引き継ぐと状態が汚染されるため、
// setUp のたびに一度DB接続とキャッシュを破棄し、各テストが必ずまっさらな
// 状態からDBを開き直せるようにしている。
//
// 注意4: RouteRepository経由のSQLite読み込み(HomeScreenのinitState内の
// 非同期処理)は、テストのfake-asyncゾーン内では完了を検知できないため、
// pumpWidget自体をrunAsync(実時間・実イベントループ)の中で行い、
// 読み込みが完了するまで実時間で少し待ってからフレームを確定させる
// (sqflite初期化に起因するテストハング対策、PR #18の修正を踏襲)。
// さらに、AuthGateを経由するようになった分、HomeScreenが実際にマウント
// されてinitStateの非同期読み込みが反映されるまでに複数フレームかかる
// ことがあるため、pump()を1回だけでなく短い間隔で数回繰り返す。
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kokudo/app.dart';
import 'package:kokudo/data/app_database.dart';
import 'package:kokudo/data/auth_repository.dart';
import 'package:kokudo/data/route_repository.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    // 前のテストが開いたDB接続・シードキャッシュを必ず破棄してから、
    // 各テストがまっさらな状態でDBを開き直せるようにする(注意3参照)。
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
    await _pumpAppAndWaitForLoad(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home screen shows the start running button', (WidgetTester tester) async {
    await _pumpAppAndWaitForLoad(tester);

    expect(find.text('ランニング開始'), findsOneWidget);
  });

  testWidgets('Root shell shows the bottom navigation with four tabs', (WidgetTester tester) async {
    await _pumpAppAndWaitForLoad(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    for (final label in ['ホーム', '計測', '記録', '地図']) {
      expect(find.widgetWithText(NavigationDestination, label), findsOneWidget);
    }
  });
}

/// RouteRepository経由のSQLite読み込み(initState内の非同期処理)は、
/// テストのfake-asyncゾーン内では完了を検知できないため、
/// pumpWidget自体をrunAsync(実時間・実イベントループ)の中で行う。
///
/// 調査の結果、この環境ではsqflite_common_ffiの初回openDatabase()
/// (ネイティブsqlite3ライブラリのロード＋ワーカーIsolateの起動を含む)に
/// かかる時間が数秒〜20秒超までかなりばらつくことを time-stamped
/// ログで確認した。固定時間待ちでは足りない場合があるため、
/// AuthGate/HomeScreenの両方が使うCircularProgressIndicator(ローディング
/// 表示)が消える=読み込み完了を検知するまで実時間でポーリングする
/// (最大60秒。通常は数百ms〜数秒で終わる)。
///
/// pumpWidget自体もrunAsync内で行っているため、ポーリングループも
/// runAsync内で完結させ、ループの各周でtester.pump()を呼んで
/// setState()の反映を都度フレームに反映させている。
Future<void> _pumpAppAndWaitForLoad(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const KokudoRunApp());
    final deadline = DateTime.now().add(const Duration(seconds: 60));
    while (DateTime.now().isBefore(deadline) &&
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      await tester.pump();
    }
  });
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}