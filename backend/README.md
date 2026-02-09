# Reading Notes Backend

読書中の引用・メモを管理する API サーバー。

## 技術スタック

| 項目 | バージョン |
|------|-----------|
| Ruby | 3.2.2 |
| Rails | 8.0.4 (API モード) |
| PostgreSQL | 16 |
| テスト | RSpec |

## DB 設計

### ER 図

```
┌─────────────┐       ┌─────────────┐
│    books    │       │    notes    │
├─────────────┤       ├─────────────┤
│ id          │◄──────│ book_id(FK) │
│ title       │  1:N  │ id          │
│ author      │       │ page        │
│ deleted_at  │       │ quote       │
│ created_at  │       │ memo        │
│ updated_at  │       │ created_at  │
└─────────────┘       │ updated_at  │
                      └─────────────┘
```

### 主な設計ポイント

- **論理削除**: Book は `deleted_at` による論理削除（Note との参照整合性を保ち、履歴を失わないため）
- **FK 制約**: `notes.book_id → books.id` は `ON DELETE RESTRICT`（Note が存在する Book の誤削除を防ぐため）
- **CHECK 制約**: `quote` 最大1000文字、`memo` 最大2000文字（アプリのバグや不正入力があってもDBで破壊的データを防ぐため）

## API エンドポイント

| Method | Path | 説明 |
|--------|------|------|
| GET | `/api/books` | Book 一覧取得 |
| POST | `/api/books` | Book 作成 |
| POST | `/api/books/:book_id/notes` | Note 作成 |
| DELETE | `/api/notes/:id` | Note 削除 |
| POST | `/api/books/:book_id/notes/bulk` | Note 一括作成（最大20件） |
| GET | `/api/books/:book_id/notes_search` | Note 検索（キーワード/ページ範囲） |

詳細は [`docs/40_api/api_overview.md`](docs/40_api/api_overview.md) を参照。

## 起動手順

### Docker Compose で起動

```bash
# 起動（初回はビルド含む）
docker compose up --build

# 初回のみ DB マイグレーション
docker compose exec web bin/rails db:migrate
```

### 動作確認

```bash
# Book 一覧取得
curl -i http://localhost:3000/api/books

# Book 作成
curl -i -X POST http://localhost:3000/api/books \
  -H "Content-Type: application/json" \
  -d '{"book":{"title":"test","author":"me"}}'
```

### 停止

```bash
# Ctrl+C で停止後
docker compose down

# DB も消したい場合
docker compose down -v
```

## テスト

```bash
# Docker 内で実行
docker compose exec web bundle exec rspec

# ローカルで実行（Ruby/PostgreSQL がローカルにある場合）
bundle exec rspec
```

現在のテストカバレッジ: 64 examples, 0 failures

## ディレクトリ構成

```
backend/
├── app/
│   ├── controllers/api/      # API コントローラ
│   ├── models/               # ActiveRecord モデル
│   ├── services/notes/       # ビジネスロジック
│   └── errors/               # カスタム例外
├── docs/
│   ├── 20_design/            # 設計方針
│   ├── 30_architecture/      # アーキテクチャ設計
│   └── 40_api/               # API 仕様
├── spec/
│   ├── requests/api/         # Request spec
│   ├── services/notes/       # Service spec
│   └── models/               # Model spec
└── db/
    ├── migrate/              # マイグレーション
    └── schema.rb             # スキーマ定義
```

## 設計ドキュメント

| ドキュメント | 内容 |
|-------------|------|
| [`docs/40_api/api_overview.md`](docs/40_api/api_overview.md) | API 仕様（エンドポイント詳細） |
| [`docs/30_architecture/error_handling.md`](docs/30_architecture/error_handling.md) | エラーハンドリング設計 |
| [`docs/30_architecture/transaction_boundary.md`](docs/30_architecture/transaction_boundary.md) | トランザクション境界 |
| [`docs/20_design/soft_delete_policy.md`](docs/20_design/soft_delete_policy.md) | 論理削除ポリシー |
