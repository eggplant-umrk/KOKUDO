// KokudoRunApp のスモークテスト。
//
// アプリが例外なく起動できること、およびホーム画面の主要な要素が
// 表示されていることを確認する。

import 'package:flutter_test/flutter_test.dart';

import 'package:kokudo/app.dart';

void main() {
  testWidgets('KokudoRunApp launches without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const KokudoRunApp());
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Home screen shows the start running button', (WidgetTester tester) async {
    await tester.pumpWidget(const KokudoRunApp());
    await tester.pump();

    expect(find.text('ランニング開始'), findsOneWidget);
  });
}
