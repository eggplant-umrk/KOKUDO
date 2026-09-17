import 'package:flutter/material.dart';

import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../models/route_checkpoint.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../utils/pace_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/hero_stage.dart';
import '../widgets/stat_tile.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onStartRunning;

  const HomeScreen({super.key, required this.onStartRunning});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RouteRepository _repo = RouteRepository.instance;

  bool _loading = true;
  String? _routeId;
  NationalRoute? _route;
  UserRouteProgress? _progress;
  double _todayKm = 0;
  double _monthKm = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final routeId = await _repo.getActiveRouteId();
    final route = await _repo.getRoute(routeId);
    final progress = await _repo.getProgress(routeId);
    final today = await _repo.todayTotalDistanceKm();
    final month = await _repo.monthTotalDistanceKm();
    if (!mounted) return;
    setState(() {
      _routeId = routeId;
      _route = route;
      _progress = progress;
      _todayKm = today;
      _monthKm = month;
      _loading = false;
    });
  }

  Future<void> _handleChangeTargetEndDate(DateTime value) async {
    final routeId = _routeId;
    if (routeId == null) return;
    setState(() {
      _progress = _progress == null
          ? UserRouteProgress(
              userId: RouteRepository.userId,
              routeId: routeId,
              currentDistanceKm: 0,
              targetEndDate: value,
              startedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            )
          : UserRouteProgress(
              userId: _progress!.userId,
              routeId: _progress!.routeId,
              currentDistanceKm: _progress!.currentDistanceKm,
              targetEndDate: value,
              runsPerWeekGoal: _progress!.runsPerWeekGoal,
              isCompleted: _progress!.isCompleted,
              startedAt: _progress!.startedAt,
              completedAt: _progress!.completedAt,
              clearedCheckpoints: _progress!.clearedCheckpoints,
              updatedAt: DateTime.now(),
            );
    });
    await _repo.updateGoal(
      routeId: routeId,
      targetEndDate: value,
      runsPerWeekGoal: _progress?.runsPerWeekGoal,
    );
  }

  Future<void> _handleChangeRunsPerWeekGoal(int? value) async {
    final routeId = _routeId;
    final progress = _progress;
    if (routeId == null || progress == null) return;
    setState(() {
      _progress = UserRouteProgress(
        userId: progress.userId,
        routeId: progress.routeId,
        currentDistanceKm: progress.currentDistanceKm,
        targetEndDate: progress.targetEndDate,
        runsPerWeekGoal: value,
        isCompleted: progress.isCompleted,
        startedAt: progress.startedAt,
        completedAt: progress.completedAt,
        clearedCheckpoints: progress.clearedCheckpoints,
        updatedAt: DateTime.now(),
      );
    });
    await _repo.updateGoal(
      routeId: routeId,
      targetEndDate: progress.targetEndDate,
      runsPerWeekGoal: value,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _route == null) {
      return Container(
        color: AppColors.bgSurface,
        child: const Center(child: CircularProgressIndicator(color: AppColors.routeSignBlue)),
      );
    }

    final route = _route!;
    final currentDistanceKm = _progress?.currentDistanceKm ?? 0;
    final targetEndDate = _progress?.targetEndDate ?? DateTime.now().add(const Duration(days: 90));
    final runsPerWeekGoal = _progress?.runsPerWeekGoal;

    RouteCheckpoint? nextCheckpoint;
    for (final c in route.checkpoints) {
      if (c.distanceKmFromStart > currentDistanceKm) {
        nextCheckpoint = c;
        break;
      }
    }
    RouteCheckpoint? lastCheckpoint;
    for (final c in route.checkpoints.reversed) {
      if (c.distanceKmFromStart <= currentDistanceKm) {
        lastCheckpoint = c;
        break;
      }
    }

    final passedLandmark = lastCheckpoint != null
        ? '${currentDistanceKm.toStringAsFixed(1)}km地点｜${lastCheckpoint.name}'
        : '${currentDistanceKm.toStringAsFixed(1)}km地点';
    final nextCheckpointLabel = nextCheckpoint != null
        ? '${nextCheckpoint.name}まであと ${(nextCheckpoint.distanceKmFromStart - currentDistanceKm).toStringAsFixed(1)}km'
        : 'まもなくゴール！';

    return Container(
      color: AppColors.bgSurface,
      child: Column(
        children: [
          Expanded(
            child: HeroStage(
              route: route,
              currentDistanceKm: currentDistanceKm,
              targetEndDate: targetEndDate,
              runsPerWeekGoal: runsPerWeekGoal,
              onChangeTargetEndDate: _handleChangeTargetEndDate,
              onChangeRunsPerWeekGoal: _handleChangeRunsPerWeekGoal,
              passedLandmark: passedLandmark,
              nextCheckpointLabel: nextCheckpointLabel,
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: StatTile(
                          label: '本日の走行距離',
                          value: formatKm(_todayKm, digits: 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          label: '今月の総走行距離',
                          value: formatKm(_monthKm),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  GradientButton(
                    onPressed: widget.onStartRunning,
                    height: 54,
                    boxShadow: const [
                      BoxShadow(color: Color(0x6122588E), blurRadius: 26, offset: Offset(0, 10)),
                    ],
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.play_arrow, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'ランニング開始',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
