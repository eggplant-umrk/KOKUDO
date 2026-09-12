import 'package:flutter/material.dart';

import '../models/national_route.dart';
import '../models/user_route_progress.dart';
import '../theme/app_colors.dart';
import '../utils/pace_utils.dart';
import 'progress_bar.dart';

DateTime _presetDate(String preset) {
  final now = DateTime.now();
  if (preset == 'thisMonth') {
    return DateTime(now.year, now.month + 1, 0);
  } else if (preset == 'nextMonth') {
    return DateTime(now.year, now.month + 2, 0);
  } else {
    return DateTime(now.year, now.month + 3, now.day);
  }
}

/// 完走ナビ（逆算計算）を、キャラクターが吹き出しで話しかけてくる形で表示する。
class GoalSpeechBubble extends StatefulWidget {
  final NationalRoute route;
  final double currentDistanceKm;
  final DateTime targetEndDate;
  final int? runsPerWeekGoal;
  final ValueChanged<DateTime> onChangeTargetEndDate;
  final ValueChanged<int?> onChangeRunsPerWeekGoal;

  const GoalSpeechBubble({
    super.key,
    required this.route,
    required this.currentDistanceKm,
    required this.targetEndDate,
    required this.runsPerWeekGoal,
    required this.onChangeTargetEndDate,
    required this.onChangeRunsPerWeekGoal,
  });

  @override
  State<GoalSpeechBubble> createState() => _GoalSpeechBubbleState();
}

class _GoalSpeechBubbleState extends State<GoalSpeechBubble> {
  bool _editing = false;
  late TextEditingController _runsController;

  @override
  void initState() {
    super.initState();
    _runsController = TextEditingController(text: widget.runsPerWeekGoal?.toString() ?? '');
  }

  @override
  void didUpdateWidget(covariant GoalSpeechBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.runsPerWeekGoal?.toString() ?? '';
    if (_runsController.text != text) {
      _runsController.value = TextEditingValue(text: text);
    }
  }

  @override
  void dispose() {
    _runsController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: widget.targetEndDate,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) {
      widget.onChangeTargetEndDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = computeGoalNav(
      widget.route,
      UserRouteProgress(
        userId: 'usr_123',
        routeId: widget.route.routeId,
        currentDistanceKm: widget.currentDistanceKm,
        targetEndDate: widget.targetEndDate,
        runsPerWeekGoal: widget.runsPerWeekGoal,
        isCompleted: false,
        startedAt: DateTime.now(),
        completedAt: null,
        clearedCheckpoints: const [],
        updatedAt: DateTime.now(),
      ),
    );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xF2FFFFFF),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            boxShadow: const [
              BoxShadow(color: Color(0x38142838), blurRadius: 26, offset: Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 24),
                child: nav.isOverdue ? _buildOverdueMessage() : _buildMessage(nav),
              ),
              const SizedBox(height: 8),
              AppProgressBar(
                ratio: nav.progressRatio,
                height: 6,
                fillGradient: AppColors.routeSignGradient,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(nav.progressRatio * 100).toStringAsFixed(1)}% 完了',
                    style: const TextStyle(color: AppColors.routeSignBlue, fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                  Text(
                    '${formatKm(widget.currentDistanceKm)} / ${formatKm(widget.route.totalDistanceKm)}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
              if (_editing) ...[
                const SizedBox(height: 6),
                const Divider(height: 1, color: AppColors.borderSubtle),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _presetChip('今月末', 'thisMonth'),
                    _presetChip('来月末', 'nextMonth'),
                    _presetChip('3ヶ月後', 'threeMonths'),
                  ],
                ),
                const SizedBox(height: 10),
                _buildDateField(),
                const SizedBox(height: 10),
                _buildRunsPerWeekField(),
              ],
            ],
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: GestureDetector(
            onTap: () => setState(() => _editing = !_editing),
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(color: AppColors.bgSurfaceRaised, shape: BoxShape.circle),
              child: const Icon(Icons.edit, size: 12, color: AppColors.textSecondary),
            ),
          ),
        ),
        Positioned(
          bottom: -8,
          left: 0,
          right: 0,
          child: Center(
            child: Transform.rotate(
              angle: 0.785398, // 45度
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: const Color(0xF2FFFFFF),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOverdueMessage() {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.55, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        children: [
          const TextSpan(text: 'あちゃー、目標の'),
          TextSpan(
            text: formatDate(widget.targetEndDate),
            style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w900),
          ),
          const TextSpan(text: 'を過ぎちゃった…新しい目標を立てよう！'),
        ],
      ),
    );
  }

  Widget _buildMessage(GoalNavResult nav) {
    return Text.rich(
      TextSpan(
        style: const TextStyle(fontSize: 13, height: 1.55, fontWeight: FontWeight.w500, color: AppColors.textPrimary),
        children: [
          const TextSpan(text: 'あと'),
          TextSpan(
            text: formatKm(nav.remainingDistanceKm),
            style: const TextStyle(color: AppColors.accentGoldText, fontWeight: FontWeight.w900),
          ),
          const TextSpan(text: '！'),
          if (nav.dailyRequiredDistanceKm != null) ...[
            const TextSpan(text: ' 1日'),
            TextSpan(
              text: formatKm(nav.dailyRequiredDistanceKm!),
              style: const TextStyle(color: AppColors.accentGoldText, fontWeight: FontWeight.w900),
            ),
            const TextSpan(text: 'ペースで一緒に頑張ろう'),
          ],
        ],
      ),
    );
  }

  Widget _presetChip(String label, String preset) {
    return GestureDetector(
      onTap: () => widget.onChangeTargetEndDate(_presetDate(preset)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgSurfaceRaised,
          border: Border.all(color: AppColors.borderSubtle),
          borderRadius: BorderRadius.circular(AppColors.radiusFull),
        ),
        child: Text(
          label,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('目標期日', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.borderSubtle),
              borderRadius: BorderRadius.circular(8),
              color: AppColors.bgSurface,
            ),
            child: Text(formatDate(widget.targetEndDate), style: const TextStyle(color: AppColors.textPrimary)),
          ),
        ),
      ],
    );
  }

  Widget _buildRunsPerWeekField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('週間ペース（週あたりの走行回数）', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextField(
          controller: _runsController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            isDense: true,
            hintText: '未設定',
            contentPadding: const EdgeInsets.all(8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.borderSubtle),
            ),
          ),
          onChanged: (value) {
            if (value.isEmpty) {
              widget.onChangeRunsPerWeekGoal(null);
              return;
            }
            final n = int.tryParse(value);
            if (n != null) {
              widget.onChangeRunsPerWeekGoal(n.clamp(0, 7).toInt());
            }
          },
        ),
      ],
    );
  }
}
