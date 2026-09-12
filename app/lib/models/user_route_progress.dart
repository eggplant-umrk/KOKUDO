import 'dart:convert';

/// ユーザー視点での路線の挑戦状況。
/// 一度にチャレンジできるのは1路線のみのため、進捗が付いていても
/// currentDistanceKm が0より大きい路線だけを「挑戦中」とみなす。
enum RouteStatus { notStarted, inProgress, completed }

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

  /// 最終更新日時。Firestore同期時に、複数端末からの更新をどちらが新しいか
  /// 判定するために使う（PR #14レビュー指摘対応）。
  final DateTime updatedAt;

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
    required this.updatedAt,
  });

  factory UserRouteProgress.fromMap(Map<String, Object?> map) {
    final updatedAtRaw = map['updated_at'] as String?;
    final startedAtRaw = map['started_at'] as String;
    return UserRouteProgress(
      userId: map['user_id'] as String,
      routeId: map['route_id'] as String,
      currentDistanceKm: (map['current_distance_km'] as num).toDouble(),
      targetEndDate: DateTime.parse(map['target_end_date'] as String),
      runsPerWeekGoal: map['runs_per_week_goal'] as int?,
      isCompleted: (map['is_completed'] as int) == 1,
      startedAt: DateTime.parse(startedAtRaw),
      completedAt: map['completed_at'] != null
          ? DateTime.parse(map['completed_at'] as String)
          : null,
      clearedCheckpoints: (jsonDecode(map['cleared_checkpoints'] as String) as List)
          .cast<String>(),
      // 旧データ（updated_at列追加前に作られたレコード）にはupdated_atが
      // 無い/空の場合があるため、その場合はstarted_atで代用する。
      updatedAt: (updatedAtRaw != null && updatedAtRaw.isNotEmpty)
          ? DateTime.parse(updatedAtRaw)
          : DateTime.parse(startedAtRaw),
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
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}