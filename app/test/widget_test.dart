// KokudoRunApp のスモークテスト。
//
// アプリが例外なく起動できること、およびホーム画面の主要な要素が
// 表示されていることを確認する。

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:kokudo/app.dart';

void main() {
  // RouteRepository/AppDatabaseがホーム画面のinitStateでSQLiteにアクセスするため、
  // ウィジェットテスト環境でもdatabaseFactoryを初期化しておく必要がある。
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('KokudoRunApp launches without throwing', (WidgetTester tester) async {
    await _pumpAppAndWaitForLoad(tester);

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home screen shows the start running button', (WidgetTester tester) async {
    await _pumpAppAndWaitForLoad(tester);

    expect(find.text('ランニング開始'), findsOneWidget);
  });
}

/// RouteRepository経由のSQLite読み込み（initState内の非同期処理）は、
/// テストのfake-asyncゾーン内では完了を検知できないため、
/// pumpWidget自体をrunAsync（実時間・実イベントループ）の中で行い、
/// 読み込みが完了するまで実時間で少し待ってからフレームを確定させる。
Future<void> _pumpAppAndWaitForLoad(WidgetTester tester) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(const KokudoRunApp());
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });
  await tester.pump();
}
