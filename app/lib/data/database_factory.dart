/// プラットフォームに応じたsqfliteのdatabaseFactory設定を、条件付きexportで
/// 切り替えるためのエントリーポイント。
///
/// - Web: sqflite_common_ffi_web（IndexedDBベース）に切り替える
/// - Android/iOS/デスクトップ: sqfliteの標準factoryをそのまま使う（何もしない）
library;

export 'database_factory_io.dart' if (dart.library.html) 'database_factory_web.dart';
