# Debug Endpoints（development 環境限定）

> **注意**: 本エンドポイントは `Rails.env.development?` の場合のみルーティングに登録される。
> production / test 環境ではアクセス不可。

## 目的

DB制約違反（NOT NULL / CHECK / FK / UNIQUE）が発生した際に、
`ApplicationController` の `rescue_from` が正しく 422 を返すことを手動で確認するためのエンドポイント。

`insert_all!` を使い、モデルバリデーションをバイパスして DB 制約違反を直接発生させる。

---

## エンドポイント

```
POST /api/debug/db_errors/:kind
```

**実装箇所**: `app/controllers/api/debug_controller.rb`
**ルーティング**: `config/routes.rb` (L15-19, `if Rails.env.development?` ガード)

---

## kind 一覧

| kind | 発生する例外 | 対象テーブル | 違反内容 |
|------|------------|------------|---------|
| `not_null` | `ActiveRecord::NotNullViolation` | books | `title: nil` を挿入 |
| `check` | `ActiveRecord::StatementInvalid` (cause: `PG::CheckViolation`) | notes | `page: 0` を挿入（CHECK page >= 1 違反） |
| `fk` | `ActiveRecord::InvalidForeignKey` | notes | `book_id: 999999` を挿入（存在しない FK） |
| `unique` | `ActiveRecord::RecordNotUnique` | users | 同一 email を 2件挿入（**注**: User モデルは未実装のため実行不可） |

---

## 例外処理の流れ

1. `insert_all!` が DB制約違反で例外を投げる
2. `DebugController` 内の `rescue_from ActiveRecord::StatementInvalid` がキャッチ
   - `cause` が `PG::CheckViolation` / `PG::NotNullViolation` / `PG::ForeignKeyViolation` / `PG::UniqueViolation` の場合 → 422
   - それ以外 → `raise`（再送出）
3. `ApplicationController` の `rescue_from` もバックアップとして機能
   - `ActiveRecord::NotNullViolation`, `ActiveRecord::InvalidForeignKey` 等 → 422

---

## curl 確認例

```bash
# NOT NULL 違反（books.title）
curl -s -X POST http://localhost:3000/api/debug/db_errors/not_null | jq
# => {"errors":["DB constraint violated"]}

# CHECK 違反（notes.page >= 1）— 要: Book が1件以上存在すること
curl -s -X POST http://localhost:3000/api/debug/db_errors/check | jq
# => {"errors":["DB constraint violated"]}

# FK 違反（notes.book_id → books.id）
curl -s -X POST http://localhost:3000/api/debug/db_errors/fk | jq
# => {"errors":["DB constraint violated"]}

# 不明な kind
curl -s -X POST http://localhost:3000/api/debug/db_errors/unknown | jq
# => {"errors":["unknown kind"]}  (400)
```

---

## レスポンス

| ステータス | 条件 | レスポンス |
|-----------|------|----------|
| 422 | DB制約違反が発生 | `{ "errors": ["DB constraint violated"] }` |
| 400 | 不明な kind | `{ "errors": ["unknown kind"] }` |

---

## 注意事項

- `unique` kind は `User` モデルを参照しているが、User テーブルは未実装のため実行すると別のエラーになる
- `check` kind は `Book.first!` を使うため、Book が 0 件の場合は `RecordNotFound` (404) になる
- 本エンドポイントはテストデータを挿入しようとするが、制約違反で必ず失敗するため DB への副作用はない
