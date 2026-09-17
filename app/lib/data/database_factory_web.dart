import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web用: sqfliteのdatabaseFactoryをIndexedDBベースのWeb実装に差し替える。
/// これによりWeb版でもRouteRepository（SQLite想定のAPI）をそのまま利用できる。
void configureDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
