// 計測画面の表示に使う純粋関数のテスト。
//
// どちらも境界値で表示が崩れやすく、実機でしか気付けない類の不具合に
// なりやすいため、ここで固定しておく。
import 'package:flutter_test/flutter_test.dart';

import 'package:kokudo/utils/pace_utils.dart';

void main() {
  group('formatDurationClock', () {
    test('1時間未満は MM:SS で表示する', () {
      expect(formatDurationClock(0), '00:00');
      expect(formatDurationClock(9), '00:09');
      expect(formatDurationClock(59), '00:59');
      expect(formatDurationClock(60), '01:00');
      expect(formatDurationClock(3599), '59:59');
    });

    test('1時間以上は H:MM:SS で表示する', () {
      // 以前は MM:SS 固定だったため「60:00」「125:30」と表示されていた。
      expect(formatDurationClock(3600), '1:00:00');
      expect(formatDurationClock(7530), '2:05:30');
      expect(formatDurationClock(36000), '10:00:00');
    });
  });

  group('formatPace', () {
    const placeholder = "--'--\"";

    test('距離が足りないうちはプレースホルダーを返す', () {
      // 走り始めは距離がほぼ0で、割り算の結果が実態を伴わない巨大な値になる。
      expect(formatPace(0, 0), placeholder);
      expect(formatPace(367, 0.024), placeholder);
      expect(formatPace(60, 0.099), placeholder);
    });

    test('経過時間が0のときはプレースホルダーを返す', () {
      expect(formatPace(0, 5.0), placeholder);
    });

    test('十分な距離があれば m\'ss" 形式で返す', () {
      expect(formatPace(300, 1.0), "5'00\"");
      expect(formatPace(36, 0.1), "6'00\"");
      expect(formatPace(1800, 5.0), "6'00\"");
    });

    test('秒が60に丸められた場合は分に繰り上げる', () {
      // secPerKm = 119.6 のとき、秒側が60に丸められる。
      // 1分60秒ではなく2分ちょうどとして表示されること。
      expect(formatPace(1196, 10.0), "2'00\"");
    });

    test('遅すぎるペースはプレースホルダーを返す', () {
      // 60分/kmちょうどまでは表示し、それを超えたら出さない。
      expect(formatPace(3600, 1.0), "60'00\"");
      expect(formatPace(3601, 1.0), placeholder);
    });
  });
}
