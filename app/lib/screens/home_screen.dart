import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/route_repository.dart';
import '../models/national_route.dart';
import '../models/route_checkpoint.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../utils/pace_utils.dart';
import '../widgets/completion_celebration.dart';
import '../widgets/gradient_button.dart';
import '../widgets/hero_stage.dart';
import '../widgets/stat_tile.dart';
import 'change_route_screen.dart';
import 'run_history_screen.dart';

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
  int _streakDays = 0;

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
    final streakDays = await _repo.currentStreakDays();
    if (!mounted) return;
    setState(() {
      _routeId = routeId;
      _route = route;
      _progress = progress;
      _todayKm = today;
      _monthKm = month;
      _streakDays = streakDays;
      _loading = false;
    });
  }

  Future<void> _handleOpenHistory() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RunHistoryScreen()),
    );
    await _load();
  }

  Future<void> _handleChangeRoute() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ChangeRouteScreen()),
    );
    await _load();
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

  /// GPS計測を使わず、後から走行距離だけを手動で記録するためのボトムシートを開く。
  /// 記録の仕組み自体はランニング計測画面の終了時([RouteRepository.recordRun])と
  /// 共通で、消費カロリーも同じ簡易換算(距離km × 62)を用いる。
  Future<void> _handleAddDistanceManually() async {
    final routeId = _routeId;
    final route = _route;
    if (routeId == null || route == null) return;

    final result = await showModalBottomSheet<({double distanceKm, int durationSeconds})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppColors.radiusLg)),
      ),
      builder: (sheetContext) => const _AddDistanceSheet(),
    );
    if (result == null || result.distanceKm <= 0 || !mounted) return;

    final caloriesBurned = (result.distanceKm * 62).round();
    final justCompleted = await _repo.recordRun(
      routeId: routeId,
      distanceKm: result.distanceKm,
      durationSeconds: result.durationSeconds,
      caloriesBurned: caloriesBurned,
    );

    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${result.distanceKm.toStringAsFixed(2)}km を追加しました'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    // 手動の追加でも完走しうるので、計測で完走したときと同じ演出を出す。
    if (justCompleted) await showCompletionCelebration(context, route);
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
              onOpenHistory: _handleOpenHistory,
              onChangeRoute: _handleChangeRoute,
              passedLandmark: passedLandmark,
              nextCheckpointLabel: nextCheckpointLabel,
              streakDays: _streakDays,
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
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: _handleAddDistanceManually,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 16, color: AppColors.textSecondary),
                    label: const Text(
                      '走行距離を手動で追加',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
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

/// [_HomeScreenState._handleAddDistanceManually] から開く、走行距離(km)だけを
/// 手動入力するためのボトムシート。GPS計測なしで、あとから距離を記録したい
/// ケース(トレッドミルで走った、記録を忘れていた等)向けの簡易入力。
class _AddDistanceSheet extends StatefulWidget {
  const _AddDistanceSheet();

  @override
  State<_AddDistanceSheet> createState() => _AddDistanceSheetState();
}

class _AddDistanceSheetState extends State<_AddDistanceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _distanceController = TextEditingController();
  final _minutesController = TextEditingController();
  final _secondsController = TextEditingController();

  @override
  void dispose() {
    _distanceController.dispose();
    _minutesController.dispose();
    _secondsController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final distanceKm = double.parse(_distanceController.text.replaceAll(',', '.'));
    final minutes = int.tryParse(_minutesController.text.trim()) ?? 0;
    final seconds = int.tryParse(_secondsController.text.trim()) ?? 0;
    final durationSeconds = minutes * 60 + seconds;
    Navigator.of(context).pop((distanceKm: distanceKm, durationSeconds: durationSeconds));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.borderSubtle,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                '走行距離を追加',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              const Text(
                'アプリ外で走った距離を、あとから記録に追加できます',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _distanceController,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(
                  hintText: '例: 5.2',
                  suffixText: 'km',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                ),
                validator: (value) {
                  final parsed = double.tryParse((value ?? '').trim().replaceAll(',', '.'));
                  if (parsed == null || parsed <= 0) return '正しい距離を入力してください';
                  if (parsed > 500) return '一度に追加できる距離が大きすぎます';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                '所要時間(任意)',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minutesController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: '分',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                      ),
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) return null;
                        final parsed = int.tryParse(trimmed);
                        if (parsed == null || parsed < 0) return '正しい分数を入力してください';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _secondsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        hintText: '0',
                        suffixText: '秒',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
                      ),
                      validator: (value) {
                        final trimmed = (value ?? '').trim();
                        if (trimmed.isEmpty) return null;
                        final parsed = int.tryParse(trimmed);
                        if (parsed == null || parsed < 0 || parsed > 59) return '0〜59の範囲で入力してください';
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GradientButton(
                onPressed: _submit,
                height: 50,
                child: const Text(
                  '追加する',
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
