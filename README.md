# KOKUDO

国道1号を走り切ろう — 走った距離を積算し、国道1号（東京〜大阪、約500km）の完走ルート上の進捗として可視化するランニング支援アプリ。

100Program 第10期（2026夏期）参加プロジェクト。3人チーム開発。

## 技術スタック

- **フロントエンド**: Flutter / Dart
- **バックエンド**: 未確定（Raspberry Pi + Docker運用 or サーバーレスBaaS で検討中）

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
