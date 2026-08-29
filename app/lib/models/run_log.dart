/// 1回分の走行記録。
class RunLog {
  final String logId;
  final String userId;
  final String routeId;
  final double distanceKm;
  final int durationSeconds;
  final double? caloriesBurned;
  final DateTime recordedAt;

  const RunLog({
    required this.logId,
    required this.userId,
    required this.routeId,
    required this.distanceKm,
    required this.durationSeconds,
    this.caloriesBurned,
    required this.recordedAt,
  });

  factory RunLog.fromMap(Map<String, Object?> map) {
    return RunLog(
      logId: map['log_id'] as String,
      userId: map['user_id'] as String,
      routeId: map['route_id'] as String,
      distanceKm: (map['distance_km'] as num).toDouble(),
      durationSeconds: map['duration_seconds'] as int,
      caloriesBurned: (map['calories_burned'] as num?)?.toDouble(),
      recordedAt: DateTime.parse(map['recorded_at'] as String),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'log_id': logId,
      'user_id': userId,
      'route_id': routeId,
      'distance_km': distanceKm,
      'duration_seconds': durationSeconds,
      'calories_burned': caloriesBurned,
      'recorded_at': recordedAt.toIso8601String(),
    };
  }
}
