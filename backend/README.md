# Reading Notes Backend

読書中の引用・メモを管理する、Ruby on Rails API mode製のバックエンドAPIです。

Bearer Token認証、ログイン中ユーザーを起点とした所有者境界、Rails validationとDB制約、Note一括登録時のtransaction、RSpecによる主要な正常系・異常系・回帰確認を実装しています。

このREADMEは、技術評価者が短時間で主要な設計判断と根拠コードへ到達できることを目的としています。

---

## Quick Evaluation Route

### 1. 30秒で概要を確認

最初に確認するポイントは以下です。

- raw tokenをDBへ保存しないBearer Token認証
- `current_user` を起点とした所有者境界
- Rails validationとDB制約によるデータ整合性
- Note一括登録時の全件成功・全件失敗
- 共通エラーレスポンスとRSpec

### 2. 主要な設計・コード・specを確認

下記の「Technical Review Map」から、設計判断・実装・spec・詳細docsへ移動できます。

### 3. 本番環境で動作確認

Base URL:

```text
https://backend-withered-voice-4962.fly.dev
```

Health Check:

```bash
curl -i https://backend-withered-voice-4962.fly.dev/healthz
```

認証を含む本番確認手順は、[API仕様・本番確認フロー](docs/40_api/api_overview.md)を参照してください。

---

## Technical Review Map

| 防ぐ問題 | 設計判断 | 主なコード | 主なspec | 詳細docs |
|---|---|---|---|---|
| raw tokenがDBから漏洩する | クライアントにはraw tokenを返し、DBにはSHA256 digestのみ保存する | [`SessionsController`](app/controllers/api/auth/sessions_controller.rb) / [`ApplicationController`](app/controllers/application_controller.rb) / [`AccessToken`](app/models/access_token.rb) | [`authentication_spec`](spec/requests/auth/authentication_spec.rb) / [`session_spec`](spec/requests/auth/session_spec.rb) / [`login_spec`](spec/requests/auth/login_spec.rb) | [認証request spec整理](docs/40_api/authentication_request_specs.md) / [API仕様](docs/40_api/api_overview.md) |
| 他ユーザー・削除済みBookへアクセスできる | `current_user.books.alive.find(...)` を取得起点にし、他人・削除済み・不存在を404として扱う | [`BooksController`](app/controllers/api/books_controller.rb) / [`NotesController`](app/controllers/api/notes_controller.rb) / [`NotesBulkController`](app/controllers/api/notes_bulk_controller.rb) / [`NotesSearchController`](app/controllers/api/notes_search_controller.rb) / [`Book`](app/models/book.rb) | [`books_spec`](spec/requests/api/books_spec.rb) / [`notes_bulk_spec`](spec/requests/api/notes_bulk_spec.rb) | [Note削除時の認可境界](docs/30_architecture/notes_destroy_authorization.md) / [論理削除ポリシー](docs/20_design/soft_delete_policy.md) |
| applicationの不具合により不正データが永続化される | Rails validationに加えてNOT NULL・FK・CHECK制約を設定する | [`User`](app/models/user.rb) / [`Book`](app/models/book.rb) / [`Note`](app/models/note.rb) / [`AccessToken`](app/models/access_token.rb) / [`migrations`](db/migrate/) / [`schema.rb`](db/schema.rb) | [`note_spec`](spec/models/note_spec.rb)（model validation） | [DB制約設計](docs/30_architecture/db_constraints.md) / [不変条件](docs/30_architecture/invariants.md) |
| Note一括登録で一部だけ保存される | Note一括登録全体をtransaction境界に置き、1件でも失敗した場合は保存件数を0件にする | [`NotesBulkController`](app/controllers/api/notes_bulk_controller.rb) / [`Notes::BulkCreate`](app/services/notes/bulk_create.rb) | [`notes_bulk_spec`](spec/requests/api/notes_bulk_spec.rb) / [`bulk_create_spec`](spec/services/notes/bulk_create_spec.rb) | [transaction境界](docs/30_architecture/transaction_boundary.md) / [Bulk API contract](docs/40_api/api_contracts/bulk_create_notes.md) / [Service層の責務](docs/30_architecture/service_layer_notes.md) |
| Controllerごとにエラー形式がばらつく | `ApplicationController` の `rescue_from` で主要例外を共通JSON形式へ変換する | [`ApplicationController`](app/controllers/application_controller.rb) / [`ApplicationErrors`](app/errors/application_errors.rb) | [`ApplicationController rescue spec`](spec/requests/application_controller_rescue_spec.rb) | [共通エラーハンドリング](docs/30_architecture/error_handling.md) |

---

## Change Case: Soft Delete / Access Boundary Improvement

関連PR: [#27 Soft Delete / Access Boundary Improvement](https://github.com/ponio-ponix/reading-notes-api-client/pull/27)

この変更では、Bookを扱う各APIで所有者境界・削除状態の確認方法が分散しないよう、
Controller入口で `current_user.books.alive.find(...)` を起点にBookを取得する構造へ整理しました。

これにより、他ユーザーのBook、削除済みBook、存在しないBookを同じ `404 Not Found` として扱い、
Notes系処理には確認済みのBookを渡す構成にしています。

確認先:

- [`app/controllers/api/books_controller.rb`](app/controllers/api/books_controller.rb)
- [`app/controllers/api/notes_controller.rb`](app/controllers/api/notes_controller.rb)
- [`app/controllers/api/notes_bulk_controller.rb`](app/controllers/api/notes_bulk_controller.rb)
- [`app/controllers/api/notes_search_controller.rb`](app/controllers/api/notes_search_controller.rb)
- [`app/models/book.rb`](app/models/book.rb)
- [`spec/requests/api/books_spec.rb`](spec/requests/api/books_spec.rb)
- [`spec/requests/api/notes_bulk_spec.rb`](spec/requests/api/notes_bulk_spec.rb)

---

## Design Decisions

### Bearer Token認証

ログイン成功時にraw tokenをクライアントへ返し、DBにはSHA256 digestのみ保存します。

有効なTokenは、以下を満たすものとして扱います。

- `revoked_at` が `nil`
- `expires_at` が現在時刻より後

ログアウト時はTokenを物理削除せず、`revoked_at` を更新して失効させます。

request specでは、主に以下を確認しています。

- 正常なBearer Tokenで保護APIへアクセスできる
- Authorization header未指定で401
- 保存済みdigestと一致しないtokenで401
- `Bearer` のみでtokenがない場合に401
- 期限切れTokenで401
- 失効済みTokenで401
- ログイン成功時にraw tokenを返す
- DBにはraw tokenではなくdigestを保存する
- ログイン失敗時にAccessTokenを作成しない
- logout後に同じTokenを再利用できない

確認先:

- [`app/controllers/api/auth/sessions_controller.rb`](app/controllers/api/auth/sessions_controller.rb)
- [`app/controllers/application_controller.rb`](app/controllers/application_controller.rb)
- [`app/models/access_token.rb`](app/models/access_token.rb)
- [`spec/requests/auth/authentication_spec.rb`](spec/requests/auth/authentication_spec.rb)
- [`spec/requests/auth/session_spec.rb`](spec/requests/auth/session_spec.rb)
- [`spec/requests/auth/login_spec.rb`](spec/requests/auth/login_spec.rb)

### 所有者境界

Book IDを受け取るAPIでは、ログイン中ユーザーの未削除Bookを取得起点にします。

```ruby
current_user.books.alive.find(params[:id])
```

これにより、以下を同じ `404 Not Found` として扱います。

- 他ユーザーが所有するBook
- 論理削除済みBook
- 存在しないBook

所有関係の有無をレスポンスから推測されにくくし、Notes系処理にも確認済みのBookを渡します。

確認先:

- [`app/controllers/api/books_controller.rb`](app/controllers/api/books_controller.rb)
- [`app/controllers/api/notes_controller.rb`](app/controllers/api/notes_controller.rb)
- [`app/controllers/api/notes_bulk_controller.rb`](app/controllers/api/notes_bulk_controller.rb)
- [`app/controllers/api/notes_search_controller.rb`](app/controllers/api/notes_search_controller.rb)
- [`app/models/book.rb`](app/models/book.rb)
- [`spec/requests/api/books_spec.rb`](spec/requests/api/books_spec.rb)
- [`spec/requests/api/notes_bulk_spec.rb`](spec/requests/api/notes_bulk_spec.rb)

### Rails validationとDB制約

application層では、利用者へ早く分かりやすいエラーを返すためにRails validationを使用します。

DB層では、applicationコードの不具合や別経路からの書き込みがあっても不正データを拒否するため、以下を設定しています。

- `NOT NULL`
- `FOREIGN KEY`
- `CHECK`
- 必要な一意制約・index

validationとDB制約は代替関係ではなく、異なる境界を守るために併用しています。

主な制約関連migration:

- [`change_notes_fk_on_delete_restrict`](db/migrate/20251215100955_change_notes_fk_on_delete_restrict.rb)
- [`make_notes_quote_not_null`](db/migrate/20251215101917_make_notes_quote_not_null.rb)
- [`add_notes_length_checks`](db/migrate/20251215102003_add_notes_length_checks.rb)
- [`harden_notes_integrity`](db/migrate/20260212033104_harden_notes_integrity.rb)
- [`make_books_title_not_null`](db/migrate/20260219104121_make_books_title_not_null.rb)
- [`add_user_to_books`](db/migrate/20260304072249_add_user_to_books.rb)
- [`make_book_user_id_not_null`](db/migrate/20260304072531_make_book_user_id_not_null.rb)

確認先:

- [`app/models`](app/models/)
- [`db/schema.rb`](db/schema.rb)
- [`spec/models/note_spec.rb`](spec/models/note_spec.rb)
- [`spec/requests/application_controller_rescue_spec.rb`](spec/requests/application_controller_rescue_spec.rb)
- [DB制約設計](docs/30_architecture/db_constraints.md)

### Note一括登録のtransaction境界

Note一括登録では、複数件のうち1件だけが失敗した場合に部分保存を残しません。

- 全件がvalidなら全件保存
- 1件でもinvalidなら保存件数は0件
- 複数行がinvalidな場合は複数エラーを返す
- エラーの `details` に対象要素の `index` と `messages` を返す
- 保存途中にDB例外が発生した場合もrollbackする
- 他ユーザー・削除済み・不存在Bookでは作成しない
- Book取得時の意図しない二重SELECTを回帰テストで検知する

ControllerはHTTP境界とレスポンス生成を担当し、処理本体は `Notes::BulkCreate` へ分離しています。

確認先:

- [`app/controllers/api/notes_bulk_controller.rb`](app/controllers/api/notes_bulk_controller.rb)
- [`app/services/notes/bulk_create.rb`](app/services/notes/bulk_create.rb)
- [`spec/requests/api/notes_bulk_spec.rb`](spec/requests/api/notes_bulk_spec.rb)
- [`spec/services/notes/bulk_create_spec.rb`](spec/services/notes/bulk_create_spec.rb)
- [`spec/support/query_counter.rb`](spec/support/query_counter.rb)
- [transaction境界](docs/30_architecture/transaction_boundary.md)
- [Bulk API contract](docs/40_api/api_contracts/bulk_create_notes.md)

### 共通エラーハンドリング

`ApplicationController` の `rescue_from` で主要例外を共通JSON形式へ変換します。

主なHTTP status:

- `400 Bad Request`
- `401 Unauthorized`
- `404 Not Found`
- `422 Unprocessable Entity`
- `500 Internal Server Error`

DB制約違反もAPIレスポンスとして扱える形式へ変換し、Controller本体を正常系の処理へ集中させます。

確認先:

- [`app/controllers/application_controller.rb`](app/controllers/application_controller.rb)
- [`app/errors/application_errors.rb`](app/errors/application_errors.rb)
- [`spec/requests/application_controller_rescue_spec.rb`](spec/requests/application_controller_rescue_spec.rb)
- [共通エラーハンドリング](docs/30_architecture/error_handling.md)

### Bookの論理削除

Book削除時は物理削除ではなく、`deleted_at` を更新します。

通常のBook一覧とNotes系APIでは、未削除Bookのみを操作対象とします。

確認先:

- [`app/controllers/api/books_controller.rb`](app/controllers/api/books_controller.rb)
- [`app/models/book.rb`](app/models/book.rb)
- [`spec/requests/api/books_spec.rb`](spec/requests/api/books_spec.rb)
- [論理削除ポリシー](docs/20_design/soft_delete_policy.md)

---

## Production

Base URL:

```text
https://backend-withered-voice-4962.fly.dev
```

Health Check:

```bash
curl -i https://backend-withered-voice-4962.fly.dev/healthz
```

本番環境はFly.ioとNeonを使用しています。無料構成のため、一定時間アクセスがない場合は初回リクエストにコールドスタート遅延が発生することがあります。

詳細なcurl例とレスポンス例:

- [API仕様・本番確認フロー](docs/40_api/api_overview.md)

---

## API Endpoints

認証が必要なエンドポイントでは、以下のheaderを使用します。

```http
Authorization: Bearer <token>
```

| Method | Path | 認証 | 説明 |
|---|---|---:|---|
| GET | `/healthz` | 不要 | Health Check |
| POST | `/api/users` | 不要 | ユーザー作成 |
| POST | `/api/auth/session` | 不要 | ログイン・Token発行 |
| DELETE | `/api/auth/session` | 必要 | ログアウト・Token失効 |
| GET | `/api/books` | 必要 | 自分の未削除Book一覧取得 |
| POST | `/api/books` | 必要 | Book作成 |
| DELETE | `/api/books/:id` | 必要 | Book論理削除 |
| POST | `/api/books/:book_id/notes` | 必要 | Note作成 |
| DELETE | `/api/books/:book_id/notes/:id` | 必要 | Note削除 |
| POST | `/api/books/:book_id/notes/bulk` | 必要 | Note一括作成 |
| GET | `/api/books/:book_id/notes_search` | 必要 | Note検索 |

詳細:

- [API仕様・本番確認フロー](docs/40_api/api_overview.md)

---

## Database

### ER Diagram

```text
┌──────────┐  1:N  ┌──────────┐  1:N  ┌──────────┐
│  users   ├───────┤  books   ├───────┤  notes   │
├──────────┤       ├──────────┤       ├──────────┤
│ id       │       │ id       │       │ id       │
│ email    │       │ user_id  │       │ book_id  │
│ password │       │ title    │       │ page     │
│ _digest  │       │ author   │       │ quote    │
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

詳細:

- [DB制約設計](docs/30_architecture/db_constraints.md)
- [`db/schema.rb`](db/schema.rb)
- [`db/migrate`](db/migrate/)

---

## Documentation

| ドキュメント | 内容 |
|---|---|
| [API仕様・本番確認フロー](docs/40_api/api_overview.md) | API仕様、認証、エラー形式、curl例 |
| [認証request spec整理](docs/40_api/authentication_request_specs.md) | 認証異常系とrequest specの対応 |
| [DB制約設計](docs/30_architecture/db_constraints.md) | validationとDB制約の責務、主要制約 |
| [不変条件](docs/30_architecture/invariants.md) | システムが維持する主要なデータ条件 |
| [共通エラーハンドリング](docs/30_architecture/error_handling.md) | 主要例外と共通JSONレスポンス |
| [transaction境界](docs/30_architecture/transaction_boundary.md) | Note一括登録の全件成功・全件失敗 |
| [Bulk API contract](docs/40_api/api_contracts/bulk_create_notes.md) | Note一括登録の入力・出力契約 |
| [Notes Service層](docs/30_architecture/service_layer_notes.md) | Notes系処理の責務分割 |
| [Note削除時の認可境界](docs/30_architecture/notes_destroy_authorization.md) | Note削除時の所有者境界 |
| [Book論理削除ポリシー](docs/20_design/soft_delete_policy.md) | `deleted_at` を使用した論理削除 |
| [開発専用debug endpoint](docs/30_architecture/debug_endpoints.md) | development環境限定の制約確認用endpoint |

---

## Tech Stack

| 項目 | バージョン・構成 |
|---|---|
| Ruby | 3.2.2 |
| Rails | 8.0.4 API mode |
| Database | PostgreSQL 16 |
| Test | RSpec |
| Local environment | Docker / Docker Compose |
| Production | Fly.io + Neon |

---

## Setup

### Docker Compose

```bash
docker compose up --build
docker compose exec web bin/rails db:prepare
```

seedを使用する場合:

```bash
docker compose exec web bin/rails db:seed
```

PostgreSQLのポートはホストへ公開していないため、ローカルのPostgreSQLと競合せず起動できます。

### Stop

```bash
docker compose down
```

DB volumeも削除する場合:

```bash
docker compose down -v
```

---

## Test

Docker内で実行:

```bash
docker compose exec -e RAILS_ENV=test web bin/rails db:prepare
docker compose exec -e RAILS_ENV=test web bundle exec rspec
```

ローカル環境で実行:

```bash
RAILS_ENV=test bin/rails db:prepare
bundle exec rspec
```

---

## Directory Structure

```text
backend/
├── app/
│   ├── controllers/api/
│   │   └── auth/
│   ├── models/
│   ├── services/notes/
│   └── errors/
├── docs/
│   ├── 20_design/
│   ├── 30_architecture/
│   └── 40_api/
├── spec/
│   ├── requests/api/
│   ├── requests/auth/
│   ├── services/notes/
│   └── models/
└── db/
    ├── migrate/
    └── schema.rb
```
