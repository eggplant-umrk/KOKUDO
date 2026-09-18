import 'dart:math' as math;

import '../models/national_route.dart';
import '../models/user_route_progress.dart';

class GoalNavResult {
  final double remainingDistanceKm;
  final int remainingDays;
  final double? dailyRequiredDistanceKm;
  final double? perRunDistanceKm;
  final double progressRatio; // 0..1
  final bool isOverdue;

  const GoalNavResult({
    required this.remainingDistanceKm,
    required this.remainingDays,
    required this.dailyRequiredDistanceKm,
    required this.perRunDistanceKm,
    required this.progressRatio,
    required this.isOverdue,
  });
}

/// 仕様書「6. 逆算計算ロジック（完走ナビ）」の実装。
///   remainingDistance = totalDistance - currentDistance
///   remainingDays = targetEndDate - currentDate
///   dailyRequiredDistance = remainingDistance / remainingDays
///   totalPlannedRuns = (remainingDays / 7) * runsPerWeekGoal
///   perRunDistance = remainingDistance / totalPlannedRuns
GoalNavResult computeGoalNav(
  NationalRoute route,
  UserRouteProgress progress, {
  DateTime? now,
}) {
  final currentTime = now ?? DateTime.now();
  final remainingDistanceKm =
      math.max(route.totalDistanceKm - progress.currentDistanceKm, 0.0);
  final endDate = progress.targetEndDate;
  final target = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
  const msPerDay = 24 * 60 * 60 * 1000;
  final rawRemainingDays =
      (target.difference(currentTime).inMilliseconds / msPerDay).ceil();
  final isOverdue = rawRemainingDays <= 0;
  final remainingDays = math.max(rawRemainingDays, 1);

  final dailyRequiredDistanceKm =
      isOverdue ? null : remainingDistanceKm / remainingDays;

  double? perRunDistanceKm;
  if (!isOverdue &&
      progress.runsPerWeekGoal != null &&
      progress.runsPerWeekGoal! > 0) {
    final totalPlannedRuns = (remainingDays / 7) * progress.runsPerWeekGoal!;
    perRunDistanceKm =
        totalPlannedRuns > 0 ? remainingDistanceKm / totalPlannedRuns : null;
  }

  final progressRatio = route.totalDistanceKm > 0
      ? math.min(progress.currentDistanceKm / route.totalDistanceKm, 1.0)
      : 0.0;

  return GoalNavResult(
    remainingDistanceKm: remainingDistanceKm,
    remainingDays: remainingDays,
    dailyRequiredDistanceKm: dailyRequiredDistanceKm,
    perRunDistanceKm: perRunDistanceKm,
    progressRatio: progressRatio,
    isOverdue: isOverdue,
  );
}

String formatKm(double value, {int digits = 1}) =>
    '${value.toStringAsFixed(digits)}km';

String formatDate(DateTime date) => '${date.year}年${date.month}月${date.day}日';

/// 1時間未満は MM:SS、1時間以上は H:MM:SS で表示する。
/// 長距離路線では1時間を超えるランも普通にあるため、分だけで表示すると
/// 「125:30」のように読み取りづらい値になってしまう。
String formatDurationClock(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// ペースが意味を持たない状態を表す表示。
const String _pacePlaceholder = "--'--\"";

/// ペースを算出できたとみなす最小距離（km）。
/// これ未満ではGPSの測位誤差が支配的で、計算しても実態を表さない。
const double _minPaceDistanceKm = 0.1;

/// 表示する上限のペース（秒/km）。60分/kmを超える値は、
/// 歩行ですらない「ほぼ止まっている」状態なので数値を出さない。
const double _maxPaceSecPerKm = 3600;

/// 1kmあたりの所要時間を m'ss" 形式で返す。
///
/// 計測開始直後は距離がほぼ0のため、割り算の結果が「253'20"」のような
/// 実態を伴わない巨大な値になる。そのまま出すと不具合に見えるので、
/// 十分な距離が貯まるまではプレースホルダーを返す。
String formatPace(int totalSeconds, double distanceKm) {
  if (distanceKm < _minPaceDistanceKm || totalSeconds <= 0) {
    return _pacePlaceholder;
  }
  final secPerKm = totalSeconds / distanceKm;
  if (secPerKm > _maxPaceSecPerKm) return _pacePlaceholder;

  var m = secPerKm ~/ 60;
  var s = (secPerKm % 60).round();
  // 60.0秒ちょうどに丸められた場合は繰り上げて分側に加算する
  // （例: secPerKm=119.6 → 従来は "1'60"" のような不正表示になっていた）
  if (s == 60) {
    s = 0;
    m += 1;
  }
  return "$m'${s.toString().padLeft(2, '0')}\"";
}
