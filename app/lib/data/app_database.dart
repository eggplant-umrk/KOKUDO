import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'database_factory.dart';

/// 端末内SQLiteのスキーマ定義とDB初期化を担うヘルパー。
///
/// national_routes / route_checkpoints は国道マスターデータ（459路線分の器）、
/// user_route_progress / run_logs はユーザーの走行記録を保持する。
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'kokudo.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    // Web版ではsqfliteの標準factoryが使えないため、IndexedDBベースの
    // factoryに差し替える（Android/iOS/デスクトップでは何もしない）。
    configureDatabaseFactory();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        for (final statement in _createTableStatements) {
          await db.execute(statement);
        }
      },
    );
  }

  static const List<String> _createTableStatements = [
    '''
    CREATE TABLE national_routes (
      route_id TEXT PRIMARY KEY,
      route_number INTEGER NOT NULL,
      name TEXT NOT NULL,
      start_lat REAL NOT NULL,
      start_lng REAL NOT NULL,
      start_label TEXT,
      end_lat REAL NOT NULL,
      end_lng REAL NOT NULL,
      end_label TEXT,
      total_distance_km REAL NOT NULL,
      geojson_path TEXT NOT NULL,
      region TEXT NOT NULL,
      difficulty TEXT NOT NULL,
      recommend_reason TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE route_checkpoints (
      checkpoint_id TEXT PRIMARY KEY,
      route_id TEXT NOT NULL REFERENCES national_routes(route_id),
      name TEXT NOT NULL,
      distance_km_from_start REAL NOT NULL,
      order_index INTEGER NOT NULL,
      lat REAL,
      lng REAL
    )
    ''',
    '''
    CREATE INDEX idx_route_checkpoints_route_id
      ON route_checkpoints(route_id)
    ''',
    '''
    CREATE TABLE user_route_progress (
      user_id TEXT NOT NULL,
      route_id TEXT NOT NULL REFERENCES national_routes(route_id),
      current_distance_km REAL NOT NULL DEFAULT 0,
      target_end_date TEXT NOT NULL,
      runs_per_week_goal INTEGER,
      is_completed INTEGER NOT NULL DEFAULT 0,
      started_at TEXT NOT NULL,
      completed_at TEXT,
      cleared_checkpoints TEXT NOT NULL DEFAULT '[]',
      PRIMARY KEY (user_id, route_id)
    )
    ''',
    '''
    CREATE TABLE run_logs (
      log_id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      route_id TEXT NOT NULL REFERENCES national_routes(route_id),
      distance_km REAL NOT NULL,
      duration_seconds INTEGER NOT NULL,
      calories_burned REAL,
      recorded_at TEXT NOT NULL
    )
    ''',
    '''
    CREATE INDEX idx_run_logs_user_route
      ON run_logs(user_id, route_id)
    ''',
  ];
}
