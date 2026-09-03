import '../models/national_route.dart';
import '../models/route_checkpoint.dart';
import '../models/run_log.dart';
import '../models/user_route_progress.dart';

const String _userId = 'usr_123';

// 注: 各路線の緯度経度・GeoJSONパスは、実際のGeoJSONデータが未用意のため
// 概略値（プレースホルダー）です。実データ投入時に差し替えてください。

// 仕様書「3. 初期収録データ（MVPスコープ）」の6路線
final List<NationalRoute> routes = [
  const NationalRoute(
    routeId: '174',
    routeNumber: 174,
    name: '国道174号',
    startPoint: RoutePoint(lat: 34.6858, lng: 135.1955, label: '兵庫県 神戸港'),
    endPoint: RoutePoint(lat: 34.6879, lng: 135.1959, label: '兵庫県 神戸市中央区'),
    totalDistanceKm: 0.187,
    geojsonPath: 'assets/geo/route_174.json',
    region: RegionKey.kinki,
    recommendReason: '日本一短い国道。即日クリア・チュートリアル用。',
    difficulty: RouteDifficulty.tutorial,
    checkpoints: [
      RouteCheckpoint(
        checkpointId: 'cp_174_01',
        routeId: '174',
        name: '神戸市中央区',
        distanceKmFromStart: 0.187,
        orderIndex: 0,
      ),
    ],
  ),
  const NationalRoute(
    routeId: '130',
    routeNumber: 130,
    name: '国道130号',
    startPoint: RoutePoint(lat: 35.6280, lng: 139.7593, label: '東京都 東京港前'),
    endPoint: RoutePoint(lat: 35.6455, lng: 139.7484, label: '東京都 港区芝'),
    totalDistanceKm: 0.5,
    geojsonPath: 'assets/geo/route_130.json',
    region: RegionKey.kanto,
    recommendReason: '散歩感覚で即達成できる超短距離枠。',
    difficulty: RouteDifficulty.tutorial,
    checkpoints: [
      RouteCheckpoint(
        checkpointId: 'cp_130_01',
        routeId: '130',
        name: '港区芝',
        distanceKmFromStart: 0.5,
        orderIndex: 0,
      ),
    ],
  ),
  const NationalRoute(
    routeId: '134',
    routeNumber: 134,
    name: '国道134号',
    startPoint: RoutePoint(lat: 35.2816, lng: 139.6720, label: '神奈川県 横須賀市'),
    endPoint: RoutePoint(lat: 35.3172, lng: 139.3122, label: '神奈川県 大磯町'),
    totalDistanceKm: 61,
    geojsonPath: 'assets/geo/route_134.json',
    region: RegionKey.kanto,
    recommendReason: '湘南海岸のシーサイドコース（初級・1〜2週間目標）。',
    difficulty: RouteDifficulty.beginner,
    checkpoints: [
      RouteCheckpoint(
        checkpointId: 'cp_134_01',
        routeId: '134',
        name: '逗子',
        distanceKmFromStart: 12,
        orderIndex: 0,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_134_02',
        routeId: '134',
        name: '鎌倉',
        distanceKmFromStart: 22,
        orderIndex: 1,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_134_03',
        routeId: '134',
        name: '藤沢',
        distanceKmFromStart: 35,
        orderIndex: 2,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_134_04',
        routeId: '134',
        name: '茅ヶ崎',
        distanceKmFromStart: 45,
        orderIndex: 3,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_134_05',
        routeId: '134',
        name: '大磯町',
        distanceKmFromStart: 61,
        orderIndex: 4,
      ),
    ],
  ),
  const NationalRoute(
    routeId: '292',
    routeNumber: 292,
    name: '国道292号',
    startPoint: RoutePoint(lat: 36.5636, lng: 138.5936, label: '群馬県 長野原町'),
    endPoint: RoutePoint(lat: 36.8993, lng: 138.2136, label: '新潟県 妙高市'),
    totalDistanceKm: 118,
    geojsonPath: 'assets/geo/route_292.json',
    region: RegionKey.chubu,
    recommendReason: '日本国道最高地点・渋峠（中級・月間目標）。',
    difficulty: RouteDifficulty.intermediate,
    checkpoints: [
      RouteCheckpoint(
        checkpointId: 'cp_292_01',
        routeId: '292',
        name: '草津',
        distanceKmFromStart: 20,
        orderIndex: 0,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_292_02',
        routeId: '292',
        name: '渋峠（最高地点）',
        distanceKmFromStart: 58,
        orderIndex: 1,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_292_03',
        routeId: '292',
        name: '野沢温泉',
        distanceKmFromStart: 90,
        orderIndex: 2,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_292_04',
        routeId: '292',
        name: '妙高市',
        distanceKmFromStart: 118,
        orderIndex: 3,
      ),
    ],
  ),
  const NationalRoute(
    routeId: '1',
    routeNumber: 1,
    name: '国道1号',
    startPoint: RoutePoint(lat: 35.6835, lng: 139.7742, label: '東京都中央区 日本橋'),
    endPoint: RoutePoint(lat: 34.6937, lng: 135.4959, label: '大阪府大阪市北区 梅田新道'),
    totalDistanceKm: 565.4,
    geojsonPath: 'assets/geo/route_1.json',
    region: RegionKey.kanto,
    recommendReason: '日本のメイン大動脈・東海道（上級・数ヶ月目標）。',
    difficulty: RouteDifficulty.advanced,
    checkpoints: [
      RouteCheckpoint(
        checkpointId: 'cp_1_01',
        routeId: '1',
        name: '品川宿',
        distanceKmFromStart: 7.8,
        orderIndex: 0,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_1_02',
        routeId: '1',
        name: '小田原',
        distanceKmFromStart: 42.0,
        orderIndex: 1,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_1_03',
        routeId: '1',
        name: '箱根峠',
        distanceKmFromStart: 95.2,
        orderIndex: 2,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_1_04',
        routeId: '1',
        name: '静岡',
        distanceKmFromStart: 180.0,
        orderIndex: 3,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_1_05',
        routeId: '1',
        name: '浜松',
        distanceKmFromStart: 260.0,
        orderIndex: 4,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_1_06',
        routeId: '1',
        name: '名古屋',
        distanceKmFromStart: 370.0,
        orderIndex: 5,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_1_07',
        routeId: '1',
        name: '京都',
        distanceKmFromStart: 520.0,
        orderIndex: 6,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_1_08',
        routeId: '1',
        name: '大阪 梅田新道',
        distanceKmFromStart: 565.4,
        orderIndex: 7,
      ),
    ],
  ),
  const NationalRoute(
    routeId: '4',
    routeNumber: 4,
    name: '国道4号',
    startPoint: RoutePoint(lat: 35.6835, lng: 139.7742, label: '東京都中央区'),
    endPoint: RoutePoint(lat: 40.8244, lng: 140.7400, label: '青森県青森市'),
    totalDistanceKm: 743,
    geojsonPath: 'assets/geo/route_4.json',
    region: RegionKey.tohoku,
    recommendReason: '陸上最長の国道（年間チャレンジ枠）。',
    difficulty: RouteDifficulty.challenge,
    checkpoints: [
      RouteCheckpoint(
        checkpointId: 'cp_4_01',
        routeId: '4',
        name: '宇都宮',
        distanceKmFromStart: 110,
        orderIndex: 0,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_4_02',
        routeId: '4',
        name: '福島',
        distanceKmFromStart: 290,
        orderIndex: 1,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_4_03',
        routeId: '4',
        name: '仙台',
        distanceKmFromStart: 350,
        orderIndex: 2,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_4_04',
        routeId: '4',
        name: '盛岡',
        distanceKmFromStart: 540,
        orderIndex: 3,
      ),
      RouteCheckpoint(
        checkpointId: 'cp_4_05',
        routeId: '4',
        name: '青森市',
        distanceKmFromStart: 743,
        orderIndex: 4,
      ),
    ],
  ),
];

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
    clearedCheckpoints: const ['神戸市中央区'],
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
    clearedCheckpoints: const ['港区芝'],
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

NationalRoute? getRoute(String routeId) {
  for (final r in routes) {
    if (r.routeId == routeId) return r;
  }
  return null;
}

UserRouteProgress? getProgress(String routeId) {
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
RouteStatus routeStatusOf(String routeId) {
  final progress = getProgress(routeId);
  if (progress == null) return RouteStatus.notStarted;
  if (progress.isCompleted) return RouteStatus.completed;
  if (progress.currentDistanceKm > 0) return RouteStatus.inProgress;
  return RouteStatus.notStarted;
}
