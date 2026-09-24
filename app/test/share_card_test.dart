// 完走シェア画像(ShareCard)が、4通りの組み合わせで例外なく組み上がることを
// 確認する。実寸(1080×1920 / 1080×1080)でレイアウトするので、はみ出しが
// あればこのテストが失敗する。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kokudo/widgets/share_card.dart';

ShareCardData _sampleData() {
  return ShareCardData(
    routeNumber: 5,
    routeName: '国道5号',
    segmentLabel: '函館市 〜 札幌市',
    totalDistanceKm: 301.2,
    days: 45,
    completedAt: DateTime(2026, 9, 22),
    routeLines: const [
      [Offset(140.73, 41.77), Offset(140.98, 42.32), Offset(141.35, 43.06)],
    ],
    prefectureRings: const [
      [Offset(139.77, 41.40), Offset(145.82, 41.40), Offset(145.82, 45.52), Offset(139.77, 45.52)],
    ],
    startPoint: const Offset(140.73, 41.77),
    goalPoint: const Offset(141.35, 43.06),
  );
}

void main() {
  for (final format in ShareCardFormat.values) {
    for (final withCharacter in [false, true]) {
      final label = 'キャラ${withCharacter ? 'あり' : 'なし'}';
      testWidgets('${format.name} / $label のシェア画像が崩れずに描ける', (tester) async {
        await tester.binding.setSurfaceSize(format.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            home: ShareCard(format: format, data: _sampleData(), showCharacter: withCharacter),
          ),
        );

        expect(find.text('完走'), findsOneWidget);
        expect(find.text('国道5号'), findsOneWidget);
        expect(find.text('函館市 〜 札幌市'), findsOneWidget);
        expect(find.text('301.2'), findsOneWidget);
        expect(find.text('45'), findsOneWidget);
        expect(find.text('2026.9.22'), findsOneWidget);
        // 標識の中身(国道 / 5 / ROUTE)。数字は路線名とは別に1つある。
        expect(find.text('ROUTE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('道なりの線が無い路線でも描ける(県の形だけになる)', (tester) async {
    await tester.binding.setSurfaceSize(ShareCardFormat.story.size);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final data = ShareCardData(
      routeNumber: 130,
      routeName: '国道130号',
      segmentLabel: '東京都港区 〜 東京都港区',
      totalDistanceKm: 0.5,
      days: 1,
      completedAt: DateTime(2026, 9, 22),
      prefectureRings: const [
        [Offset(138.9, 35.5), Offset(139.9, 35.5), Offset(139.9, 35.9), Offset(138.9, 35.9)],
      ],
    );

    await tester.pumpWidget(
      MaterialApp(home: ShareCard(format: ShareCardFormat.story, data: data)),
    );

    expect(find.text('国道130号'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
