# Reading Notes Backend

データ整合性と障害耐性を重視して設計した
読書引用管理用 REST API。


## Production URL

Base URL:
https://backend-withered-voice-4962.fly.dev

Example:

```bash
curl https://backend-withered-voice-4962.fly.dev/api/books

```
## Design Intent

本APIは以下を重視して設計した。

- **DB制約によるデータ整合性の保証**
  - NOT NULL（books.title, notes.page 等） / CHECK / FK を用いてアプリ層の不具合でも破壊的データを防ぐ
- **例外系の統一**
  - 400 / 404 / 422 / 500 を ApplicationController で一元処理
  - DB制約違反（NotNullViolation, InvalidForeignKey, RecordNotUnique, CheckViolation）は 422 に変換
- **無料サーバーレス構成での実運用再現**
  - Fly.io + Neon による公開環境
  - コールドスタート遅延を含めて説明可能な状態

目的は  
**「壊れないAPIを設計・説明できることの証明」**  
である。

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

# 初回のみ DB マイグレーション + シードデータ投入
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails db:seed
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
| [`docs/30_architecture/debug_endpoints.md`](docs/30_architecture/debug_endpoints.md) | デバッグ用エンドポイント（development限定） |
| [`docs/20_design/soft_delete_policy.md`](docs/20_design/soft_delete_policy.md) | 論理削除ポリシー |


## Runtime Performance Characteristics（コールドスタートによる遅延）

### 概要

- **初回アクセス遅延:** 約5秒  
- **2回目以降:** 約200ms  

この遅延は、**一定時間アクセスが無かった後の最初のリクエストのみ**発生する。

---

### 根本原因

本遅延はアプリケーション性能ではなく、  
**サーバーレスインフラのコールドスタート**によるもの。

- **Fly.io のオートストップ**
  - トラフィックが無いと VM が自動停止する。
  - 次回アクセス時に VM 起動待ちが発生する。

- **Neon（Serverless Postgres）のコールドスタート**
  - 初回接続時に DB コンピュートが再開される。
  - 最初のクエリに数秒の遅延が追加される。

---

### 根拠（本番ログ）

**遅いリクエスト**

- Total: 約5.1秒  
- ActiveRecord: 約3.6秒  
- **VM 起動直後に発生**

**通常リクエスト**

- Total: 約218ms  
- ActiveRecord: 約213ms  

これにより：

- SQL 自体は本質的に遅くない  
- 遅延は **コールドスタート時のみ**発生  
- アプリケーションコードやクエリ設計は **ボトルネックではない**

---

### 追加検証（curl による実測）

```bash
# 1回目（コールドスタート）
time curl -o /dev/null -s https://backend-withered-voice-4962.fly.dev/api/books

# 2回目（ウォーム）
time curl -o /dev/null -s https://backend-withered-voice-4962.fly.dev/api/books
```
---

### なぜ対策を行っていないか

考えられる対策：

- Fly.io マシンの常時起動  
- Neon の有料プラン利用（コールドスタート回避）  
- 定期 keep-alive ping の導入  

本プロジェクトでは **意図的に未実施**とした。

理由：

- 本アプリは **ポートフォリオ用途**  
- **完全無料のサーバーレス構成**での運用を前提としている  
- コールドスタート遅延は **仕様上のトレードオフ**であり不具合ではない

---

### 結論

観測された遅延は：

- **インフラ起因である**
- **再現性があり説明可能**
- **無料サーバーレス運用の範囲では許容可能**

したがって、  
**アプリケーションレベルの最適化は不要**と判断した。

---

