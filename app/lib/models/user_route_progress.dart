import 'dart:convert';

/// ユーザーごとの国道走破進捗・目標設定。
class UserRouteProgress {
  final String userId;
  final String routeId;
  final double currentDistanceKm;
  final DateTime targetEndDate;
  final int? runsPerWeekGoal;
  final bool isCompleted;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<String> clearedCheckpoints;

  const UserRouteProgress({
    required this.userId,
    required this.routeId,
    required this.currentDistanceKm,
    required this.targetEndDate,
    this.runsPerWeekGoal,
    this.isCompleted = false,
    required this.startedAt,
    this.completedAt,
    this.clearedCheckpoints = const [],
  });

  factory UserRouteProgress.fromMap(Map<String, Object?> map) {
    return UserRouteProgress(
      userId: map['user_id'] as String,
      routeId: map['route_id'] as String,
      currentDistanceKm: (map['current_distance_km'] as num).toDouble(),
      targetEndDate: DateTime.parse(map['target_end_date'] as String),
      runsPerWeekGoal: map['runs_per_week_goal'] as int?,
      isCompleted: (map['is_completed'] as int) == 1,
      startedAt: DateTime.parse(map['started_at'] as String),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      clearedCheckpoints: (jsonDecode(map['cleared_checkpoints'] as String) as List)
          .cast<String>(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'user_id': userId,
      'route_id': routeId,
      'current_distance_km': currentDistanceKm,
      'target_end_date': targetEndDate.toIso8601String(),
      'runs_per_week_goal': runsPerWeekGoal,
      'is_completed': isCompleted ? 1 : 0,
      'started_at': startedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'cleared_checkpoints': jsonEncode(clearedCheckpoints),
    };
  }
}
