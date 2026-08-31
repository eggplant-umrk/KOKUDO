import 'package:flutter/material.dart';

import '../data/mock_data.dart' as mock;
import '../models/route_models.dart';
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
  // デモ用: 完走ナビの目標日・週間ペースをこの画面のローカル状態として保持
  String _targetEndDate = '2026-10-31';
  int? _runsPerWeekGoal = 3;
  final double _currentDistanceKm = 42.5;

  @override
  Widget build(BuildContext context) {
    final route = mock.getRoute(mock.activeRouteId)!;

    Checkpoint? nextCheckpoint;
    for (final c in route.checkpoints) {
      if (c.distanceFromStartKm > _currentDistanceKm) {
        nextCheckpoint = c;
        break;
      }
    }
    Checkpoint? lastCheckpoint;
    for (final c in route.checkpoints.reversed) {
      if (c.distanceFromStartKm <= _currentDistanceKm) {
        lastCheckpoint = c;
        break;
      }
    }

    final passedLandmark = lastCheckpoint != null
        ? '${_currentDistanceKm.toStringAsFixed(1)}km地点｜${lastCheckpoint.name}'
        : '${_currentDistanceKm.toStringAsFixed(1)}km地点';
    final nextCheckpointLabel = nextCheckpoint != null
        ? '${nextCheckpoint.name}まであと ${(nextCheckpoint.distanceFromStartKm - _currentDistanceKm).toStringAsFixed(1)}km'
        : 'まもなくゴール！';

    return Container(
      color: AppColors.bgSurface,
      child: Column(
        children: [
          Expanded(
            child: HeroStage(
              route: route,
              currentDistanceKm: _currentDistanceKm,
              targetEndDate: _targetEndDate,
              runsPerWeekGoal: _runsPerWeekGoal,
              onChangeTargetEndDate: (v) => setState(() => _targetEndDate = v),
              onChangeRunsPerWeekGoal: (v) => setState(() => _runsPerWeekGoal = v),
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
                          value: formatKm(mock.todayTotalDistanceKm(), digits: 2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StatTile(
                          label: '今月の総走行距離',
                          value: formatKm(mock.monthTotalDistanceKm()),
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
