// 完走シェア画像の「かかった日数」の起点(その国道を最初に走った日時)を
// 正しく選べることを確認する。国道を選んだ日ではなく、走った日から数えるため。
import 'package:flutter_test/flutter_test.dart';
import 'package:kokudo/models/run_log.dart';
import 'package:kokudo/screens/share_completion_screen.dart';

RunLog _log(String id, String routeId, DateTime at) {
  return RunLog(
    logId: id,
    userId: 'u1',
    routeId: routeId,
    distanceKm: 5,
    durationSeconds: 1800,
    recordedAt: at,
  );
}

void main() {
  test('その国道の走行記録のうち、いちばん古い日時を返す', () {
    final logs = [
      _log('a', 'route_1', DateTime(2026, 10, 12, 18)),
      _log('b', 'route_1', DateTime(2026, 10, 12, 7)),
      _log('c', 'route_4', DateTime(2026, 10, 1, 7)),
    ];
    expect(firstRunAtOf(logs, 'route_1'), DateTime(2026, 10, 12, 7));
  });

  test('ほかの国道の記録は見ない', () {
    final logs = [_log('c', 'route_4', DateTime(2026, 10, 1))];
    expect(firstRunAtOf(logs, 'route_1'), isNull);
  });

  test('記録が無ければ null(呼び出し側で選んだ日に戻す)', () {
    expect(firstRunAtOf(const [], 'route_1'), isNull);
  });
}
