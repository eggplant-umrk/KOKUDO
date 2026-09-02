import '../models/route_models.dart';

const String _userId = 'usr_123';

// 仕様書「3. 初期収録データ（MVPスコープ）」の6路線
final List<NationalRoute> routes = [
  const NationalRoute(
    routeId: 174,
    routeNumber: 174,
    name: '国道174号',
    startPoint: '兵庫県 神戸港',
    endPoint: '兵庫県 神戸市中央区',
    totalDistanceKm: 0.187,
    region: RegionKey.kinki,
    recommendReason: '日本一短い国道。即日クリア・チュートリアル用。',
    difficulty: RouteDifficulty.tutorial,
    checkpoints: [Checkpoint(name: '神戸市中央区', distanceFromStartKm: 0.187)],
  ),
  const NationalRoute(
    routeId: 130,
    routeNumber: 130,
    name: '国道130号',
    startPoint: '東京都 東京港前',
    endPoint: '東京都 港区芝',
    totalDistanceKm: 0.5,
    region: RegionKey.kanto,
    recommendReason: '散歩感覚で即達成できる超短距離枠。',
    difficulty: RouteDifficulty.tutorial,
    checkpoints: [Checkpoint(name: '港区芝', distanceFromStartKm: 0.5)],
  ),
  const NationalRoute(
    routeId: 134,
    routeNumber: 134,
    name: '国道134号',
    startPoint: '神奈川県 横須賀市',
    endPoint: '神奈川県 大磯町',
    totalDistanceKm: 61,
    region: RegionKey.kanto,
    recommendReason: '湘南海岸のシーサイドコース（初級・1〜2週間目標）。',
    difficulty: RouteDifficulty.beginner,
    checkpoints: [
      Checkpoint(name: '逗子', distanceFromStartKm: 12),
      Checkpoint(name: '鎌倉', distanceFromStartKm: 22),
      Checkpoint(name: '藤沢', distanceFromStartKm: 35),
      Checkpoint(name: '茅ヶ崎', distanceFromStartKm: 45),
      Checkpoint(name: '大磯町', distanceFromStartKm: 61),
    ],
  ),
  const NationalRoute(
    routeId: 292,
    routeNumber: 292,
    name: '国道292号',
    startPoint: '群馬県 長野原町',
    endPoint: '新潟県 妙高市',
    totalDistanceKm: 118,
    region: RegionKey.chubu,
    recommendReason: '日本国道最高地点・渋峠（中級・月間目標）。',
    difficulty: RouteDifficulty.intermediate,
    checkpoints: [
      Checkpoint(name: '草津', distanceFromStartKm: 20),
      Checkpoint(name: '渋峠（最高地点）', distanceFromStartKm: 58),
      Checkpoint(name: '野沢温泉', distanceFromStartKm: 90),
      Checkpoint(name: '妙高市', distanceFromStartKm: 118),
    ],
  ),
  const NationalRoute(
    routeId: 1,
    routeNumber: 1,
    name: '国道1号',
    startPoint: '東京都中央区 日本橋',
    endPoint: '大阪府大阪市北区 梅田新道',
    totalDistanceKm: 565.4,
    region: RegionKey.kanto,
    recommendReason: '日本のメイン大動脈・東海道（上級・数ヶ月目標）。',
    difficulty: RouteDifficulty.advanced,
    checkpoints: [
      Checkpoint(name: '品川宿', distanceFromStartKm: 7.8),
      Checkpoint(name: '小田原', distanceFromStartKm: 42.0),
      Checkpoint(name: '箱根峠', distanceFromStartKm: 95.2),
      Checkpoint(name: '静岡', distanceFromStartKm: 180.0),
      Checkpoint(name: '浜松', distanceFromStartKm: 260.0),
      Checkpoint(name: '名古屋', distanceFromStartKm: 370.0),
      Checkpoint(name: '京都', distanceFromStartKm: 520.0),
      Checkpoint(name: '大阪 梅田新道', distanceFromStartKm: 565.4),
    ],
  ),
  const NationalRoute(
    routeId: 4,
    routeNumber: 4,
    name: '国道4号',
    startPoint: '東京都中央区',
    endPoint: '青森県青森市',
    totalDistanceKm: 743,
    region: RegionKey.tohoku,
    recommendReason: '陸上最長の国道（年間チャレンジ枠）。',
    difficulty: RouteDifficulty.challenge,
    checkpoints: [
      Checkpoint(name: '宇都宮', distanceFromStartKm: 110),
      Checkpoint(name: '福島', distanceFromStartKm: 290),
      Checkpoint(name: '仙台', distanceFromStartKm: 350),
      Checkpoint(name: '盛岡', distanceFromStartKm: 540),
      Checkpoint(name: '青森市', distanceFromStartKm: 743),
    ],
  ),
];

// ユーザーの進捗（挑戦中/完走済み/未着手が混在するデモデータ）
// 挑戦は一度に1路線のみのため、進捗が付いていても currentDistanceKm が
// 0より大きい路線だけを「挑戦中」とみなす（詳しくは routeStatusOf 参照）。
final List<UserRouteProgress> userProgress = [
  const UserRouteProgress(
    userId: _userId,
    routeId: 174,
    currentDistanceKm: 0.187,
    targetEndDate: '2026-08-20',
    runsPerWeekGoal: null,
    isCompleted: true,
    startedAt: '2026-08-18T08:00:00Z',
    completedAt: '2026-08-18T08:05:00Z',
    clearedCheckpoints: ['神戸市中央区'],
  ),
  const UserRouteProgress(
    userId: _userId,
    routeId: 130,
    currentDistanceKm: 0.5,
    targetEndDate: '2026-08-20',
    runsPerWeekGoal: null,
    isCompleted: true,
    startedAt: '2026-08-19T08:00:00Z',
    completedAt: '2026-08-19T08:04:00Z',
    clearedCheckpoints: ['港区芝'],
  ),
  const UserRouteProgress(
    // まだ着手していない路線として保持（0km = 未挑戦扱い）
    userId: _userId,
    routeId: 134,
    currentDistanceKm: 0,
    targetEndDate: '2026-09-15',
    runsPerWeekGoal: null,
    isCompleted: false,
    startedAt: '2026-08-20T08:00:00Z',
    completedAt: null,
    clearedCheckpoints: [],
  ),
  const UserRouteProgress(
    // 現在挑戦中のメインチャレンジ（ホーム画面で表示）
    userId: _userId,
    routeId: 1,
    currentDistanceKm: 42.5,
    targetEndDate: '2026-10-31',
    runsPerWeekGoal: 3,
    isCompleted: false,
    startedAt: '2026-08-01T08:00:00Z',
    completedAt: null,
    clearedCheckpoints: ['品川宿'],
  ),
  const UserRouteProgress(
    userId: _userId,
    routeId: 292,
    currentDistanceKm: 0,
    targetEndDate: '2026-12-31',
    runsPerWeekGoal: 2,
    isCompleted: false,
    startedAt: '2026-08-25T08:00:00Z',
    completedAt: null,
    clearedCheckpoints: [],
  ),
  const UserRouteProgress(
    userId: _userId,
    routeId: 4,
    currentDistanceKm: 0,
    targetEndDate: '2027-08-01',
    runsPerWeekGoal: null,
    isCompleted: false,
    startedAt: '2026-08-25T08:00:00Z',
    completedAt: null,
    clearedCheckpoints: [],
  ),
];

// アクティブに挑戦中の路線ID（ホーム画面のメイン表示に使用）
const int activeRouteId = 1;

final List<RunLog> runLogs = [
  RunLog(
    logId: 'log_001',
    userId: _userId,
    routeId: 1,
    distanceKm: 5.24,
    durationSeconds: 1694,
    caloriesBurned: 312,
    recordedAt: DateTime.now(),
  ),
  RunLog(
    logId: 'log_002',
    userId: _userId,
    routeId: 1,
    distanceKm: 8.1,
    durationSeconds: 2610,
    caloriesBurned: 486,
    recordedAt: DateTime.now().subtract(const Duration(days: 2)),
  ),
  RunLog(
    logId: 'log_003',
    userId: _userId,
    routeId: 134,
    distanceKm: 6.3,
    durationSeconds: 1980,
    caloriesBurned: 372,
    recordedAt: DateTime.now().subtract(const Duration(days: 5)),
  ),
  RunLog(
    logId: 'log_004',
    userId: _userId,
    routeId: 1,
    distanceKm: 7.4,
    durationSeconds: 2340,
    caloriesBurned: 431,
    recordedAt: DateTime.now().subtract(const Duration(days: 9)),
  ),
];

// 仕様書「1. プロダクト概要」より、将来的に収録される全国の一般国道の路線総数
const int nationalRouteCount = 459;

// 全459路線の実延長合計の概算値（km）。カバー率計算のための参考値。
const double nationalNetworkTotalKm = 55000;

int completedRouteCount() => userProgress.where((p) => p.isCompleted).length;

double cumulativeDistanceKm() =>
    userProgress.fold(0.0, (sum, p) => sum + p.currentDistanceKm);

double coverageRatio() {
  final ratio = cumulativeDistanceKm() / nationalNetworkTotalKm;
  return ratio < 1 ? ratio : 1;
}

NationalRoute? getRoute(int routeId) {
  for (final r in routes) {
    if (r.routeId == routeId) return r;
  }
  return null;
}

UserRouteProgress? getProgress(int routeId) {
  for (final p in userProgress) {
    if (p.routeId == routeId) return p;
  }
  return null;
}

double todayTotalDistanceKm() {
  final now = DateTime.now();
  final startOfToday = DateTime(now.year, now.month, now.day);
  return runLogs
      .where((l) => !l.recordedAt.isBefore(startOfToday))
      .fold(0.0, (sum, l) => sum + l.distanceKm);
}

double monthTotalDistanceKm() {
  final now = DateTime.now();
  return runLogs
      .where((l) => l.recordedAt.year == now.year && l.recordedAt.month == now.month)
      .fold(0.0, (sum, l) => sum + l.distanceKm);
}

/// 一度にチャレンジできるのは1路線のみのため、進捗が付いていても
/// currentDistanceKm が0より大きい路線だけを「挑戦中」とみなす。
RouteStatus routeStatusOf(int routeId) {
  final progress = getProgress(routeId);
  if (progress == null) return RouteStatus.notStarted;
  if (progress.isCompleted) return RouteStatus.completed;
  if (progress.currentDistanceKm > 0) return RouteStatus.inProgress;
  return RouteStatus.notStarted;
}
