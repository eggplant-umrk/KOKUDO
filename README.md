# KOKUDO

走った実際の距離（ランニング・ウォーキング）を全国の一般国道にマッピングし、バーチャルに走破していく記録アプリ。

キャラクターと一緒に走り、設定した目標期日までに国道を完走して、日本地図を光で塗りつぶす。

100Program 第10期（2026夏期）参加プロジェクト。3人チーム開発。

## 技術スタック

- **フロントエンド**: Flutter / Dart
- **地図描画**: MapLibre GL (`maplibre_gl`)
- **GPS / 距離計測**: `geolocator` / `health`
- **ローカルDB**: SQLite (`sqflite`)（国道のGeoJSONと走行ログを端末内に保持）
- **バックエンド・認証**: Firebase (Authentication, Firestore)
- **インフラ管理**: Terraform（GCP / Firebase構成）

## 画面構成

1. **ホーム画面**: キャラクターのランニングアニメーション、設定期日からの逆算完走ナビ、走破プログレスバー
2. **ランニング計測画面**: 走行距離・経過時間の巨大数値表示、ペース・カロリー、チェックポイントまでの距離表示
3. **走破・地図コレクション画面**: 全国国道のインタラクティブ地図（未走破=グレー、挑戦中=ネオンブルー、完走=ゴールド）、実績サマリー

## 初期収録データ（MVPスコープ）

全459路線のデータ構造を持たせつつ、以下6路線を先行アクティブ化する。

| 路線 | 距離 | 想定難易度 |
| --- | --- | --- |
| 国道174号（兵庫） | 約187m | チュートリアル |
| 国道130号（東京） | 約0.5km | — |
| 国道134号（神奈川・湘南） | 約61km | 初級 |
| 国道292号（群馬〜新潟・渋峠） | 約118km | 中級 |
| 国道1号（東京〜大阪） | 実延長約565km | 上級 |
| 国道4号（東京〜青森） | 実延長約743km | 年間チャレンジ |

## データモデル

- **NationalRoute**（国道マスター）: `route_id`, `route_number`, `name`, `start_point`, `end_point`, `total_distance_km`, `geojson_path`, `checkpoints`
- **UserRouteProgress**（進捗・目標）: `user_id`, `route_id`, `current_distance_km`, `target_end_date`, `runs_per_week_goal`, `is_completed`, `started_at`, `completed_at`, `cleared_checkpoints`
- **RunLog**（走行履歴）: `log_id`, `user_id`, `route_id`, `distance_km`, `duration_seconds`, `calories_burned`, `recorded_at`

雛形は `app/lib/models/` と `app/lib/data/app_database.dart` を参照。

## ディレクトリ構成

```
KOKUDO/
├── app/    # Flutterアプリ本体（flutter create で生成）
├── docs/   # 設計資料・議事メモ
└── README.md
```

## 開発の始め方

```
cd app
flutter pub get
flutter run
```

## 運用ルール

Git / GitHub の運用ルールは [`docs/GitHub運用ルール.md`](docs/GitHub運用ルール.md) を参照してください。
