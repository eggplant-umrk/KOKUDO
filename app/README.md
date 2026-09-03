# 国道ラン（国道完走チャレンジアプリ）— Flutter実装

Flutter（Dart）で作成した、モバイル向けUIプロトタイプです。GPS計測・バックエンド接続は未接続で、インメモリのモックデータで動作します。

## セットアップ

```bash
cd app
flutter pub get
flutter run -d chrome        # Webで確認する場合
flutter run -d web-server --web-port=8080  # ヘッドレスなWebサーバーとして起動する場合
```

画面上部の切り替えタブ（dev-nav）から3画面を確認できます（タブ自体はデモ用で、実プロダクトのUIには含まれません）。

## 画面構成

- **① ホーム画面** (`lib/screens/home_screen.dart`) — キャラクター走行アニメーション、完走ナビ（逆算計算）、本日/今月の走行距離、ランニング開始ボタン
- **② ランニング計測画面** (`lib/screens/running_screen.dart`) — 距離・経過時間の巨大表示、ペース・カロリー、国道ミニステップバー、一時停止/長押し終了
- **③ 走破・地図コレクション画面** (`lib/screens/map_collection_screen.dart`) — 実績サマリー、地方別フィルター、路線ネットワーク、ルート一覧

画面の切り替え・状態受け渡しは `lib/app.dart` の `RootShell` が担っています。

## ディレクトリ構成

- `lib/models/` — データモデル（`national_route.dart` / `route_checkpoint.dart` / `user_route_progress.dart` / `run_log.dart`）。SQLite（`sqflite`）との `fromMap`/`toMap` を備えた、正式な永続化対応モデルです。
- `lib/data/` — `mock_data.dart`（インメモリのデモデータ）と `app_database.dart`（SQLiteスキーマ定義。現時点ではまだ画面からは未接続）
- `lib/screens/` — 3つの主要画面
- `lib/widgets/` — 画面を構成する部品（キャラクターアニメーション領域、地図パネル、ルートカード等）
- `lib/theme/` — 配色などのデザイントークン
- `lib/utils/` — 完走ナビの逆算計算・日付/ペースのフォーマット関数

## キャラクターアニメーションと背景演出

- `assets/character-run.webp` — キャラクターのアニメーションWebP（未コミットの場合は `assets/character-run.gif`、それも無い場合はアイコンのフォールバック表示に切り替わります）。
- `assets/road-bg.webp` — 走路の背景イラスト。

## 計算ロジック

`lib/utils/pace_utils.dart` の `computeGoalNav()` が、仕様書「6. 逆算計算ロジック」の式（残り距離／残り日数／1日あたり必要距離／週ペース時の1回あたり距離）を実装しています。

## データモデル

`lib/models/` に、仕様書「5. データモデル設計」に対応するモデルを定義しています。`lib/data/mock_data.dart` は現状インメモリのデモデータですが、モデル自体は `sqflite` 経由のSQLite永続化（`lib/data/app_database.dart` のスキーマ）にそのまま対応できる形にしてあります。実際のDB接続時は、`mock_data.dart` の各関数をSQLiteクエリに差し替えるだけで画面側はそのまま動作する構成を想定しています。

## 未実装（今後の拡張ポイント）

- GPS実測（`geolocator`相当のGPS/位置情報連携）
- SQLiteへの実際の読み書き接続（現在は `app_database.dart` のスキーマのみで、画面はまだ `mock_data.dart` を参照）
- 実際の日本地図（GeoJSON描画等）への差し替え。現在の③画面は簡易的な路線ネットワーク表示です
- 認証・バックエンド接続
