import 'dart:async';

import 'package:flutter/material.dart';

import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../models/route_checkpoint.dart';
import '../models/run_log.dart';
import '../theme/app_colors.dart';
import '../utils/pace_utils.dart';
import '../widgets/gradient_button.dart';
import '../widgets/progress_bar.dart';
import '../widgets/stat_tile.dart';

/// ランニング計測画面。バッテリー消費を抑えるため純黒の背景を使う（OLED対策）。
class RunningScreen extends StatefulWidget {
  final ValueChanged<RunResult> onFinish;

  const RunningScreen({super.key, required this.onFinish});

  @override
  State<RunningScreen> createState() => _RunningScreenState();
}

class _RunningScreenState extends State<RunningScreen> with SingleTickerProviderStateMixin {
  // デモ用の想定ペース（≈5'43"/km）
  // TODO: 実GPS化（geolocator + Haversine公式）で置き換え予定。
  static const double _avgSpeedKmph = 10.5;
  static const double _kmPerSecond = _avgSpeedKmph / 3600;
  static const int _holdToEndMs = 1200;

  final RouteRepository _repo = RouteRepository.instance;

  bool _loading = true;
  String? _routeId;
  NationalRoute? _route;
  double _startDistanceKm = 0;

  bool _hasStarted = false;
  double _distanceKm = 0;
  int _durationSeconds = 0;
  bool _isPaused = false;
  bool _finishing = false;

  Timer? _timer;
  late final AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _holdToEndMs),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _finish();
        }
      });
    _load();
  }

  Future<void> _load() async {
    final routeId = await _repo.getActiveRouteId();
    final route = await _repo.getRoute(routeId);
    final progress = await _repo.getProgress(routeId);
    if (!mounted) return;
    setState(() {
      _routeId = routeId;
      _route = route;
      _startDistanceKm = progress?.currentDistanceKm ?? 0;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _holdController.dispose();
    super.dispose();
  }

  void _restartTicker() {
    _timer?.cancel();
    if (!_hasStarted || _isPaused) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _durationSeconds += 1;
        _distanceKm += _kmPerSecond;
      });
    });
  }

  void _handleStart() {
    setState(() {
      _hasStarted = true;
      _isPaused = false;
    });
    _restartTicker();
  }

  void _togglePause() {
    setState(() => _isPaused = !_isPaused);
    _restartTicker();
  }

  void _cancelHold() {
    if (!mounted) return;
    if (_holdController.status == AnimationStatus.completed) return;
    _holdController.stop();
    _holdController.value = 0;
  }

  Future<void> _finish() async {
    _holdController.stop();
    _holdController.value = 0;
    if (_finishing) return;
    _finishing = true;

    _timer?.cancel();
    final routeId = _routeId;
    final caloriesBurned = (_distanceKm * 62).round();
    final result = RunResult(
      distanceKm: _distanceKm,
      durationSeconds: _durationSeconds,
      caloriesBurned: caloriesBurned,
    );

    if (routeId != null && _distanceKm > 0) {
      await _repo.recordRun(
        routeId: routeId,
        distanceKm: _distanceKm,
        durationSeconds: _durationSeconds,
        caloriesBurned: caloriesBurned,
      );
    }

    if (!mounted) return;
    widget.onFinish(result);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _route == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: AppColors.routeSignBlue)),
      );
    }

    final route = _route!;
    final caloriesBurned = (_distanceKm * 62).round();
    final currentAbsoluteKm = _startDistanceKm + _distanceKm;

    RouteCheckpoint? nextCheckpoint;
    for (final c in route.checkpoints) {
      if (c.distanceKmFromStart > currentAbsoluteKm) {
        nextCheckpoint = c;
        break;
      }
    }
    var prevCheckpointKm = _startDistanceKm;
    for (final c in route.checkpoints) {
      if (c.distanceKmFromStart <= currentAbsoluteKm) {
        prevCheckpointKm = c.distanceKmFromStart;
      }
    }
    var stepRatio = 1.0;
    if (nextCheckpoint != null) {
      final denom = (nextCheckpoint.distanceKmFromStart - prevCheckpointKm);
      final safeDenom = denom < 0.001 ? 0.001 : denom;
      stepRatio = ((currentAbsoluteKm - prevCheckpointKm) / safeDenom).clamp(0.0, 1.0).toDouble();
    }

    return Container(
      color: Colors.black,
      // 注: ノッチ／ステータスバーの回避は常に画面最上部にあるdev-navが
      // 既に確保しているため、ここではボトム（ホームインジケーター）のみ対応する。
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildMiniStepBar(route, nextCheckpoint, currentAbsoluteKm, stepRatio),
            Expanded(child: _buildRunMain()),
            _buildSubstatusGrid(caloriesBurned),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStepBar(
    NationalRoute route,
    RouteCheckpoint? nextCheckpoint,
    double currentAbsoluteKm,
    double stepRatio,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '次のチェックポイント：${nextCheckpoint?.name ?? route.endPoint.label ?? ''}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.55)),
                ),
              ),
              Text(
                nextCheckpoint != null
                    ? 'あと ${(nextCheckpoint.distanceKmFromStart - currentAbsoluteKm).toStringAsFixed(1)}km'
                    : 'ゴール目前',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.85)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AppProgressBar(
            ratio: stepRatio,
            height: 3,
            trackColor: Colors.white.withValues(alpha: 0.14),
            fillGradient: AppColors.routeSignGradient,
          ),
        ],
      ),
    );
  }

  Widget _buildRunMain() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _distanceKm.toStringAsFixed(2),
                style: const TextStyle(
                  fontSize: 96,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  letterSpacing: -2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'km',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.6)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatDurationClock(_durationSeconds),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
          if (!_hasStarted) ...[
            const SizedBox(height: 18),
            Text(
              'スタートをタップして計測を開始',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.45)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubstatusGrid(int caloriesBurned) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
      child: Row(
        children: [
          Expanded(
            child: StatTile(
              label: '現在のペース',
              value: formatPace(_durationSeconds, _distanceKm),
              valueFontSize: 26,
              dark: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatTile(
              label: '消費カロリー',
              value: '$caloriesBurned kcal',
              valueFontSize: 26,
              dark: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      child: SizedBox(
        height: 76,
        child: !_hasStarted
            ? GradientButton(
                onPressed: _handleStart,
                height: 76,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow, color: Colors.white, size: 22),
                    SizedBox(width: 8),
                    Text('スタート', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  ],
                ),
              )
            : Row(
                children: [
                  _buildPauseButton(),
                  const SizedBox(width: 16),
                  Expanded(child: _buildEndButton()),
                ],
              ),
      ),
    );
  }

  Widget _buildPauseButton() {
    return GestureDetector(
      onTap: _togglePause,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: 0.08),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
        ),
        child: Icon(_isPaused ? Icons.play_arrow : Icons.pause, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildEndButton() {
    return Listener(
      onPointerDown: (_) => _holdController.forward(from: 0),
      onPointerUp: (_) => _cancelHold(),
      onPointerCancel: (_) => _cancelHold(),
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, child) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(AppColors.radiusFull),
            child: Container(
              height: 76,
              color: const Color(0x2EE4536A),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: FractionallySizedBox(
                      widthFactor: _holdController.value,
                      alignment: Alignment.centerLeft,
                      child: Container(color: AppColors.danger.withValues(alpha: 0.22)),
                    ),
                  ),
                  child!,
                ],
              ),
            ),
          );
        },
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('終了', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900, fontSize: 15)),
            SizedBox(height: 2),
            Text(
              '長押しで確定',
              style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
