// ドメインモデル定義（仕様書「5. データモデル設計」に対応）

/// 8地方の区分。
enum RegionKey {
  hokkaido,
  tohoku,
  kanto,
  chubu,
  kinki,
  chugoku,
  shikoku,
  kyushuOkinawa,
}

const Map<RegionKey, String> regionLabel = {
  RegionKey.hokkaido: '北海道',
  RegionKey.tohoku: '東北',
  RegionKey.kanto: '関東',
  RegionKey.chubu: '中部',
  RegionKey.kinki: '近畿',
  RegionKey.chugoku: '中国',
  RegionKey.shikoku: '四国',
  RegionKey.kyushuOkinawa: '九州・沖縄',
};

/// 路線の難易度。
enum RouteDifficulty { tutorial, beginner, intermediate, advanced, challenge }

/// ユーザー視点での路線の挑戦状況。
enum RouteStatus { notStarted, inProgress, completed }

class Checkpoint {
  final String name;
  final double distanceFromStartKm;

  const Checkpoint({required this.name, required this.distanceFromStartKm});
}

class NationalRoute {
  final int routeId;
  final int routeNumber;
  final String name;
  final String startPoint;
  final String endPoint;
  final double totalDistanceKm;
  final RegionKey region;
  final String recommendReason;
  final RouteDifficulty difficulty;
  final List<Checkpoint> checkpoints;

  const NationalRoute({
    required this.routeId,
    required this.routeNumber,
    required this.name,
    required this.startPoint,
    required this.endPoint,
    required this.totalDistanceKm,
    required this.region,
    required this.recommendReason,
    required this.difficulty,
    required this.checkpoints,
  });
}

class UserRouteProgress {
  final String userId;
  final int routeId;
  final double currentDistanceKm;

  /// ISO日付文字列（yyyy-MM-dd）。ユーザーが設定した目標期日。
  final String targetEndDate;

  /// 週間目標走行回数（任意）。
  final int? runsPerWeekGoal;
  final bool isCompleted;
  final String startedAt;
  final String? completedAt;
  final List<String> clearedCheckpoints;

  const UserRouteProgress({
    required this.userId,
    required this.routeId,
    required this.currentDistanceKm,
    required this.targetEndDate,
    required this.runsPerWeekGoal,
    required this.isCompleted,
    required this.startedAt,
    required this.completedAt,
    required this.clearedCheckpoints,
  });
}

class RunLog {
  final String logId;
  final String userId;
  final int routeId;
  final double distanceKm;
  final int durationSeconds;
  final int caloriesBurned;
  final DateTime recordedAt;

  const RunLog({
    required this.logId,
    required this.userId,
    required this.routeId,
    required this.distanceKm,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.recordedAt,
  });
}

/// ランニング計測画面の終了時に呼び出し元へ渡す結果。
class RunResult {
  final double distanceKm;
  final int durationSeconds;
  final int caloriesBurned;

  const RunResult({
    required this.distanceKm,
    required this.durationSeconds,
    required this.caloriesBurned,
  });
}
