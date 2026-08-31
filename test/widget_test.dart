import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kokudo_run_app/app.dart';

void main() {
  testWidgets('起動時にホーム画面（dev-nav・CTAボタン）が表示される', (WidgetTester tester) async {
    await tester.pumpWidget(const KokudoRunApp());
    await tester.pump();

    // 画面切り替え用のdev-navタブ
    expect(find.text('① ホーム'), findsOneWidget);
    expect(find.text('② ランニング計測'), findsOneWidget);
    expect(find.text('③ 走破・地図'), findsOneWidget);

    // ホーム画面下部の「ランニング開始」CTAボタン
    expect(find.text('ランニング開始'), findsOneWidget);
  });
}
