import '../models/run_log.dart';
import '../models/user_route_progress.dart';

const String _userId = 'usr_123';

// 注: 国道のマスターデータ(459路線)は assets/routes/national_routes.json にあり、
// RouteCatalog が読み込む。このファイルにはデモ用の進捗・走行ログだけが残っている
// (リリース前に取り除く予定。リリース前修正項目 1-1)。

// ユーザーの進捗（挑戦中/完走済み/未着手が混在するデモデータ）
// 挑戦は一度に1路線のみのため、進捗が付いていても currentDistanceKm が
// 0より大きい路線だけを「挑戦中」とみなす（詳しくは routeStatusOf 参照）。
final List<UserRouteProgress> userProgress = [
  UserRouteProgress(
    userId: _userId,
    routeId: '174',
    currentDistanceKm: 0.187,
    targetEndDate: DateTime(2026, 8, 20),
    runsPerWeekGoal: null,
    isCompleted: true,
    startedAt: DateTime.utc(2026, 8, 18, 8, 0, 0),
    completedAt: DateTime.utc(2026, 8, 18, 8, 5, 0),
    clearedCheckpoints: const ['税関前交差点（終点）'],
    updatedAt: DateTime.now(),
  ),
  UserRouteProgress(
    userId: _userId,
    routeId: '130',
    currentDistanceKm: 0.5,
    targetEndDate: DateTime(2026, 8, 20),
    runsPerWeekGoal: null,
    isCompleted: true,
    startedAt: DateTime.utc(2026, 8, 19, 8, 0, 0),
    completedAt: DateTime.utc(2026, 8, 19, 8, 4, 0),
    clearedCheckpoints: const ['芝三丁目交差点（終点）'],
    updatedAt: DateTime.now(),
  ),
  UserRouteProgress(
    // まだ着手していない路線として保持（0km = 未挑戦扱い）
    userId: _userId,
    routeId: '134',
    currentDistanceKm: 0,
    targetEndDate: DateTime(2026, 9, 15),
    runsPerWeekGoal: null,
    isCompleted: false,
    startedAt: DateTime.utc(2026, 8, 20, 8, 0, 0),
    completedAt: null,
    clearedCheckpoints: const [],
    updatedAt: DateTime.now(),
  ),
  UserRouteProgress(
    // 現在挑戦中のメインチャレンジ（ホーム画面で表示）
    userId: _userId,
    routeId: '1',
    currentDistanceKm: 42.5,
    targetEndDate: DateTime(2026, 10, 31),
    runsPerWeekGoal: 3,
    isCompleted: false,
    startedAt: DateTime.utc(2026, 8, 1, 8, 0, 0),
    completedAt: null,
    clearedCheckpoints: const ['品川宿'],
    updatedAt: DateTime.now(),
  ),
  UserRouteProgress(
    userId: _userId,
    routeId: '292',
    currentDistanceKm: 0,
    targetEndDate: DateTime(2026, 12, 31),
    runsPerWeekGoal: 2,
    isCompleted: false,
    startedAt: DateTime.utc(2026, 8, 25, 8, 0, 0),
    completedAt: null,
    clearedCheckpoints: const [],
    updatedAt: DateTime.now(),
  ),
  UserRouteProgress(
    userId: _userId,
    routeId: '4',
    currentDistanceKm: 0,
    targetEndDate: DateTime(2027, 8, 1),
    runsPerWeekGoal: null,
    isCompleted: false,
    startedAt: DateTime.utc(2026, 8, 25, 8, 0, 0),
    completedAt: null,
    clearedCheckpoints: const [],
    updatedAt: DateTime.now(),
  ),
];

// アクティブに挑戦中の路線ID（ホーム画面のメイン表示に使用）
const String activeRouteId = '1';

final List<RunLog> runLogs = [
  RunLog(
    logId: 'log_001',
    userId: _userId,
    routeId: '1',
    distanceKm: 5.24,
    durationSeconds: 1694,
    caloriesBurned: 312,
    recordedAt: DateTime.now(),
  ),
  RunLog(
    logId: 'log_002',
    userId: _userId,
    routeId: '1',
    distanceKm: 8.1,
    durationSeconds: 2610,
    caloriesBurned: 486,
    recordedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  RunLog(
    logId: 'log_003',
    userId: _userId,
    routeId: '134',
    distanceKm: 6.3,
    durationSeconds: 1980,
    caloriesBurned: 372,
    recordedAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  RunLog(
    logId: 'log_004',
    userId: _userId,
    routeId: '1',
    distanceKm: 7.4,
    durationSeconds: 2340,
    caloriesBurned: 431,
    recordedAt: DateTime.now().subtract(const Duration(days: 9)),
  ),
];
