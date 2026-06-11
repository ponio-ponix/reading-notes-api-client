# Reading Notes Backend

データ整合性と障害耐性を重視して設計した読書引用管理用 REST API。  
Bearer Token 認証と、ログイン中ユーザーごとの所有者ベースのデータアクセス制御を実装しています。

---

## Production URL

Base URL:

```text
https://backend-withered-voice-4962.fly.dev
```

Health Check:

```bash
curl https://backend-withered-voice-4962.fly.dev/healthz
```

---

## Quick Evaluation Route

本番環境で最小限の動作確認を行う場合は、以下の順で確認できます。

1. `GET /healthz`
2. `POST /api/users`
3. `POST /api/auth/session`
4. `GET /api/books` with Bearer Token
5. `POST /api/books` with Bearer Token
6. `DELETE /api/books/:id` with Bearer Token

詳細なAPI仕様・レスポンス例は [`docs/40_api/api_overview.md`](docs/40_api/api_overview.md) を参照してください。

---

## Design Intent

本APIは以下を重視して設計しています。

- **DB制約によるデータ整合性の保証**
  - `NOT NULL` / `CHECK` / `FK` を用いて、アプリ層の不具合でも破壊的データを防ぐ

- **Bearer Token 認証と所有者スコープ**
  - ログイン時に発行した raw token はクライアントにのみ返却し、DBには SHA256 digest のみ保存
  - データ操作APIでは `current_user.books` を起点に所有者境界を担保

- **Controller入口での境界統一**
  - Book ID を受け取るAPIでは、Controller側で `current_user.books.alive.find(...)` により、認証・所有権・未削除Bookであることを確認
  - 他ユーザーBook・削除済みBook・存在しないBookは `404 Not Found` として扱い、所有関係を外部に露出しない

- **Controller / Service の責務分離**
  - ControllerはHTTP境界の確認とレスポンス生成を担当
  - Service層には確認済みのBookを渡し、Bulk作成やSearchなどの処理本体に責務を集中

- **Bulk作成のトランザクション境界**
  - Note一括作成では、全件成功 or 全件失敗のトランザクションとして扱う
  - 一部のNoteがinvalidな場合、DBには1件も作成しない
  - `details` に `index` と `messages` を返し、どの要素が失敗したかを示す

- **エラーハンドリングの共通化**
  - `ApplicationController` の `rescue_from` で主要な例外を一元処理
  - `400` / `401` / `404` / `422` / `500` を統一したレスポンス形式で返す
  - DB制約違反も `422 Unprocessable Entity` に変換する

- **Book の論理削除**
  - Book削除時は物理削除ではなく `deleted_at` を更新
  - 通常の一覧・Notes系APIでは削除済みBookを対象外にする

- **無料サーバーレス構成での実運用再現**
  - Fly.io + Neon による公開環境
  - コールドスタート遅延を含めて説明可能な状態

目的は、**「壊れにくいAPIを設計・実装・説明できることの証明」**です。

---

## Documentation

| ドキュメント | 内容 |
|-------------|------|
| [`docs/40_api/api_overview.md`](docs/40_api/api_overview.md) | API仕様・認証・エラー形式・本番確認済みフロー |
| [`docs/30_architecture/db_constraints.md`](docs/30_architecture/db_constraints.md) | DB制約設計 |
| [`docs/30_architecture/error_handling.md`](docs/30_architecture/error_handling.md) | 共通エラーハンドリング |
| [`docs/30_architecture/transaction_boundary.md`](docs/30_architecture/transaction_boundary.md) | Bulk作成のトランザクション境界 |
| [`docs/30_architecture/service_layer_notes.md`](docs/30_architecture/service_layer_notes.md) | Notes系Service層の責務 |
| [`docs/30_architecture/notes_destroy_authorization.md`](docs/30_architecture/notes_destroy_authorization.md) | Note削除時の認可境界 |
| [`docs/20_design/soft_delete_policy.md`](docs/20_design/soft_delete_policy.md) | Book論理削除ポリシー |
| [`docs/30_architecture/debug_endpoints.md`](docs/30_architecture/debug_endpoints.md) | DB制約エラー確認用の開発専用エンドポイント。`Rails.env.development?` の場合のみroutesに追加 |

---

## 技術スタック

| 項目 | バージョン |
|------|-----------|
| Ruby | 3.2.2 |
| Rails | 8.0.4 API mode |
| PostgreSQL | 16 |
| Test | RSpec |
| Production | Fly.io + Neon |

---

## DB 設計

### ER 図

```text
┌──────────┐  1:N  ┌──────────┐  1:N  ┌──────────┐
│  users   ├───────┤  books   ├───────┤  notes   │
├──────────┤       ├──────────┤       ├──────────┤
│ id       │       │ id       │       │ id       │
│ email    │       │ user_id  │       │ book_id  │
│ password │       │ title    │       │ page     │
│  _digest │       │ author   │       │ quote    │
└────┬─────┘       │ deleted_at       │ memo     │
     │ 1:N         └──────────┘       └──────────┘
     ▼
┌──────────────────┐
│  access_tokens   │
├──────────────────┤
│ id               │
│ user_id          │
│ token_digest     │
│ expires_at       │
│ revoked_at       │
│ last_used_at     │
└──────────────────┘
```

詳細なDB制約は [`docs/30_architecture/db_constraints.md`](docs/30_architecture/db_constraints.md) を参照してください。

---

## API エンドポイント

認証が必要なエンドポイントには `Authorization: Bearer <token>` ヘッダーが必要です。

| Method | Path | 認証 | 説明 |
|--------|------|------|------|
| GET | `/healthz` | 不要 | Health Check |
| POST | `/api/users` | 不要 | ユーザー作成 |
| POST | `/api/auth/session` | 不要 | ログイン（Token発行） |
| DELETE | `/api/auth/session` | 必要 | ログアウト（Token失効） |
| GET | `/api/books` | 必要 | 自分の未削除Book一覧取得 |
| POST | `/api/books` | 必要 | Book作成 |
| DELETE | `/api/books/:id` | 必要 | Book論理削除 |
| POST | `/api/books/:book_id/notes` | 必要 | Note作成 |
| DELETE | `/api/books/:book_id/notes/:id` | 必要 | Note削除 |
| POST | `/api/books/:book_id/notes/bulk` | 必要 | Note一括作成 |
| GET | `/api/books/:book_id/notes_search` | 必要 | Note検索（キーワード / ページ範囲） |

詳細は [`docs/40_api/api_overview.md`](docs/40_api/api_overview.md) を参照してください。

---

## 起動手順

### Docker Compose で起動

PostgreSQL のポートはホストに公開していません。  
ローカルに PostgreSQL がインストールされていても衝突せず起動できます。

```bash
# 起動（初回はビルド含む）
docker compose up --build

# 初回のみ（development DB の作成 + schema/migration 適用）
docker compose exec web bin/rails db:prepare

# 初回のみ（seed を入れたい場合）
docker compose exec web bin/rails db:seed
```

---

## 動作確認

ローカルでAPIを確認する場合は `http://localhost:3000` をBase URLとして実行してください。  
本番環境で確認する場合は `https://backend-withered-voice-4962.fly.dev` に置き換えて実行できます。

詳細なcurl例・レスポンス例は [`docs/40_api/api_overview.md`](docs/40_api/api_overview.md) を参照してください。

---

## 停止

```bash
# Ctrl+C で停止後
docker compose down

# DB も消したい場合
docker compose down -v
```

---

## テスト

```bash
# 初回のみ（test DB の作成 + schema/migration 適用）
docker compose exec -e RAILS_ENV=test web bin/rails db:prepare

# Docker 内で実行
docker compose exec -e RAILS_ENV=test web bundle exec rspec

# ローカルで実行（Ruby/PostgreSQL がローカルにある場合）
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
```

---

## ディレクトリ構成

```text
backend/
├── app/
│   ├── controllers/api/      # API controllers
│   │   └── auth/             # Auth controller
│   ├── models/               # ActiveRecord models
│   ├── services/notes/       # Business logic
│   └── errors/               # Custom exceptions
├── docs/
│   ├── 20_design/            # Design policies
│   ├── 30_architecture/      # Architecture docs
│   └── 40_api/               # API docs
├── spec/
│   ├── requests/api/         # Request specs
│   ├── requests/auth/        # Authentication request specs
│   ├── services/notes/       # Service specs
│   └── models/               # Model specs
└── db/
    ├── migrate/              # Migrations
    └── schema.rb             # Schema definition
```

---

## Runtime Performance Characteristics

本番環境は Fly.io + Neon の無料サーバーレス構成で運用しています。

一定時間アクセスがない場合、初回リクエストでコールドスタートが発生します。

- 初回アクセス: 約5秒
- 2回目以降: 約200ms

これはアプリケーションコードやSQLの性能問題ではなく、Fly.io VM と Neon compute の再開による遅延です。  
ポートフォリオ用途では、無料運用のトレードオフとして許容しています。

確認例:

```bash
time curl -o /dev/null -s https://backend-withered-voice-4962.fly.dev/healthz
```