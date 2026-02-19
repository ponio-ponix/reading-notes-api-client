# Architecture（実装現況）

## 1. システム全体構成

- バックエンド: Ruby on Rails 8.0.4（API-only モード）
  - `config/application.rb`: `config.api_only = true`
  - `/api/**` で JSON を返す REST API（6 エンドポイント）
- フロントエンド: React 19 + TypeScript + Vite
  - `fetch` で API を呼び出す SPA
  - `vite.config.ts` で `/api` を `http://localhost:3000` にプロキシ
- DB: PostgreSQL 16
  - `docker-compose.yml`: `image: postgres:16`
- 認証機構は存在しない（シングルユーザー前提）

---

## 2. レイヤー構造（Rails 側）

実装上のレイヤーは以下の3層。Repository 層は存在しない。

### 2.1 Controller（Presentation 層）

- HTTP リクエストからパラメータを受け取る
- 一部のアクションは Service を呼び出し、戻り値を JSON にして返す
- 一部のアクションは ActiveRecord モデルを直接操作している（後述 §3.1）

### 2.2 Service（Application 層）

- ビジネスロジック・トランザクション制御を担当
- 実在するクラス: `Notes::BulkCreate`, `Notes::SearchNotes` の 2 クラスのみ
- `app/services/notes/` に配置

### 2.3 Model（Domain 層 + ActiveRecord）

- `Book`, `Note` の 2 モデル
- バリデーション・コールバック・スコープをモデルに定義
- ActiveRecord を直接使用（Repository 層による抽象化はない）

### 2.4 存在しない層

- **Repository 層**: `app/repositories/` は存在しない。Controller および Service が ActiveRecord モデルを直接操作している。
- **UseCase 層**: 独立した UseCase クラスは存在しない。Service がその役割を兼ねている。

---

## 3. 主なコンポーネント

### 3.1 Controller

#### `Api::BooksController`（`app/controllers/api/books_controller.rb`）

| action | 処理内容 | ActiveRecord 直接操作 |
|--------|---------|---------------------|
| `index` | `Book.alive.order(created_at: :desc)` で取得し JSON 返却 | Yes |
| `create` | `Book.new(book_params)` → `book.save` で作成 | Yes |

Service を経由していない。Controller 内で ActiveRecord を直接呼んでいる。

#### `Api::NotesController`（`app/controllers/api/notes_controller.rb`）

| action | 処理内容 | ActiveRecord 直接操作 |
|--------|---------|---------------------|
| `create` | `@book.notes.create!(note_params)` で作成 | Yes |
| `destroy` | `Note.find(params[:id])` → `note.destroy!` で削除 | Yes |

`before_action :set_book` で `Book.alive.find(params[:book_id])` を実行。Service を経由していない。

#### `Api::NotesBulkController`（`app/controllers/api/notes_bulk_controller.rb`）

| action | 処理内容 | ActiveRecord 直接操作 |
|--------|---------|---------------------|
| `create` | `Notes::BulkCreate.call(...)` を呼び出し | No（Service 経由） |

`notes_params` メソッドでリクエスト構造の検証（配列か、各要素がオブジェクトか）を行い、不正な場合は `ApplicationErrors::BadRequest` を raise する。

#### `Api::NotesSearchController`（`app/controllers/api/notes_search_controller.rb`）

| action | 処理内容 | ActiveRecord 直接操作 |
|--------|---------|---------------------|
| `index` | `Notes::SearchNotes.call(...)` を呼び出し | No（Service 経由） |

#### `HealthController`（`app/controllers/health_controller.rb`）

| action | 処理内容 |
|--------|---------|
| `show` | `{ ok: true }` を返す（`GET /healthz`） |

`ActionController::API` を直接継承（`ApplicationController` ではない）。

#### `Api::DebugController`（`app/controllers/api/debug_controller.rb`）

| action | 処理内容 |
|--------|---------|
| `db_errors` | `POST /api/debug/db_errors/:kind` — DB制約違反を意図的に再現する |

- **development 環境限定**（`routes.rb`: `if Rails.env.development?`）
- kind: `not_null` / `check` / `fk` / `unique`
- `insert_all!` でモデルバリデーションをバイパスし、DB制約違反を直接発生させる
- 詳細は [`docs/30_architecture/debug_endpoints.md`](debug_endpoints.md) を参照

---

### 3.2 Service

#### `Notes::BulkCreate`（`app/services/notes/bulk_create.rb`）

- 入力: `book_id`, `notes_params`（配列）
- 処理:
  1. 空配列チェック・上限チェック（MAX 20 件）→ 違反時 `ApplicationErrors::BadRequest`
  2. `Book.alive.find(book_id)` で Book 取得 → 不在時 `ActiveRecord::RecordNotFound`
  3. 全件のバリデーションを先に実行
  4. 1 件でもエラーがあれば `BulkInvalid`（index + messages 付き）を raise
  5. `ActiveRecord::Base.transaction { notes.each(&:save!) }` で一括保存
- トランザクション: **あり**（L42-44）
- 独自例外: `Notes::BulkCreate::BulkInvalid`（`errors` 属性に `[{ index:, messages: }]` を保持）

#### `Notes::SearchNotes`（`app/services/notes/search_notes.rb`）

- 入力: `book_id`, `query`, `page_from`, `page_to`, `page`, `limit`
- 処理:
  1. パラメータの正規化・型チェック → 違反時 `ApplicationErrors::BadRequest`
  2. `Book.alive.find(book_id)` で Book 取得
  3. `WHERE page >= ? AND page <= ?` でページ範囲絞り込み
  4. `WHERE quote ILIKE :pattern OR memo ILIKE :pattern` でスペース区切り AND 検索
  5. `ORDER BY created_at DESC` + OFFSET/LIMIT でページネーション
- トランザクション: **なし**（読み取り専用のため）
- 戻り値: `[records, meta]`（meta: `total_count`, `page`, `limit`, `total_pages`）

---

### 3.3 Model

#### `Book`（`app/models/book.rb`）

```ruby
has_many :notes
scope :alive, -> { where(deleted_at: nil) }
validates :title, presence: true
```

#### `Note`（`app/models/note.rb`）

```ruby
belongs_to :book
validates :quote, presence: true, length: { maximum: 1000 }
validates :memo,  length: { maximum: 2000 }, allow_nil: true
validates :page,  numericality: { only_integer: true, greater_than_or_equal_to: 1 }
before_validation :strip_text  # quote, memo の前後空白を除去
```

#### 存在しないモデル

`Tag`, `NoteTag` は未実装。テーブル・モデルファイルともに存在しない。

---

## 4. DB スキーマ（`db/schema.rb`）

### books テーブル

| カラム | 型 | 制約 |
|--------|-----|------|
| id | bigint PK | NOT NULL |
| title | string | NOT NULL |
| author | string | — |
| deleted_at | datetime | — |
| created_at | datetime | NOT NULL |
| updated_at | datetime | NOT NULL |

インデックス: `index_books_on_deleted_at`

### notes テーブル

| カラム | 型 | 制約 |
|--------|-----|------|
| id | bigint PK | NOT NULL |
| book_id | bigint FK | NOT NULL, references books (on_delete: :restrict) |
| page | integer | NOT NULL, CHECK (page >= 1) |
| quote | text | NOT NULL, CHECK (char_length(quote) <= 1000) |
| memo | text | NULL 許容, CHECK (memo IS NULL OR char_length(memo) <= 2000) |
| created_at | datetime | NOT NULL |
| updated_at | datetime | NOT NULL |

インデックス: `index_notes_on_book_id`, `index_notes_on_book_id_and_page`

---

## 5. トランザクション

- `ActiveRecord::Base.transaction` が使われている箇所: `Notes::BulkCreate`（L42-44）の 1 箇所のみ
- Controller にトランザクションは存在しない
- 単件の Note 作成（`NotesController#create`）は `create!` 単発呼び出しであり、明示的なトランザクションは貼っていない

---

## 6. エラーハンドリング

`ApplicationController`（`app/controllers/application_controller.rb`）に `rescue_from` を集約。

| 例外 | ステータス | レスポンス形式 | ログレベル |
|------|-----------|--------------|-----------|
| `ApplicationErrors::BadRequest` | 400 | `{ "errors": ["message"] }` | warn |
| `ActionController::ParameterMissing` | 400 | `{ "errors": ["message"] }` | warn |
| `ActiveRecord::RecordNotFound` | 404 | `{ "errors": ["message"] }` | info |
| `Notes::BulkCreate::BulkInvalid` | 422 | `{ "errors": [{ "index": N, "messages": [...] }] }` | info |
| `ActiveRecord::RecordInvalid` | 422 | `{ "errors": ["Full message 1", ...] }` | info |
| `ActiveRecord::RecordNotDestroyed` | 422 | `{ "errors": ["Full message 1"] }` | info |
| `ActiveRecord::NotNullViolation` | 422 | `{ "errors": ["DB constraint violated"] }` | warn |
| `ActiveRecord::InvalidForeignKey` | 422 | `{ "errors": ["DB constraint violated"] }` | warn |
| `ActiveRecord::RecordNotUnique` | 422 | `{ "errors": ["DB constraint violated"] }` | warn |
| `ActiveRecord::CheckViolation`（※） | 422 | `{ "errors": ["DB constraint violated"] }` | warn |
| `StandardError`（production のみ） | 500 | `{ "errors": ["Internal server error"] }` | error |

※ `CheckViolation` は `defined?(ActiveRecord::CheckViolation)` ガード付き。

エラーレスポンスのルート構造は全て `{ "errors": [...] }`（配列）。
Bulk API のみ配列要素が `{ index:, messages: }` のオブジェクト形式。
DB制約違反は固定メッセージ `"DB constraint violated"` で統一。

---

## 7. 認証

認証機構は存在しない。`current_user` メソッド・認証フィルタ・認証関連 gem のいずれも実装されていない。
