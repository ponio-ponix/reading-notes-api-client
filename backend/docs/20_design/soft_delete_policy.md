# Soft Delete Policy (Books)

## 目的

Book は物理削除せず、`deleted_at` による論理削除として扱う。

削除済みBookは通常のAPI導線では「存在しないもの」として扱い、  
Book一覧・Note作成・Bulk作成・Note検索などの対象から除外する。

---

## 基本方針

- Book削除時は物理削除せず、`deleted_at` に削除時刻を記録する
- `deleted_at IS NULL` のBookだけを通常のAPI対象にする
- 削除済みBookは、通常導線では `404 Not Found` として扱う
- 物理削除によるcascadeは行わない
- `default_scope` は使わず、明示的な `alive` scope を使う

---

## API上の扱い

削除済みBookは、クライアントから見ると「存在しないリソース」として扱う。

以下の場合は `404 Not Found` を返す。

- Bookが存在しない
- Bookが削除済み
- Bookが他ユーザー所有

レスポンス形式は共通エラー仕様に従う。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

存在しない場合、削除済みの場合、他ユーザー所有の場合を区別しないことで、  
リソースの存在有無や所有関係を外部に露出しない。

---

## Controller入口での境界統一

Book ID を受け取るAPIでは、Controller入口で以下を確認する。

- 認証済みユーザーであること
- ログイン中ユーザーが所有するBookであること
- 削除済みBookではないこと

実装上は、以下のように取得する。

```ruby
book = current_user.books.alive.find(params[:book_id])
```

この時点で、存在確認・所有者境界・未削除Book確認をまとめて行う。

---

## Notes系APIでの責務分離

Notes系APIでは、ControllerがHTTP境界を確認し、Serviceには確認済みのBookを渡す。

```text
Controller
→ 認証・所有権・alive確認
→ current_user.books.alive.find(params[:book_id])

Service
→ 確認済みBookを前提に処理本体を実行
```

この方針により、Service内で `Book.find` や `Book.alive.find(book_id)` を再実行しない。

理由は以下。

- Service側で所有者境界を取り違えるリスクを下げる
- Controller入口でHTTP上の境界を明確にする
- 同じBook取得の二重クエリを避ける
- Bulk / Search / Create でBook取得ルールを統一する

---

## 対象API

以下のAPIでは、削除済みBookを対象外にする。

| API | 削除済みBookの扱い |
|-----|------------------|
| `GET /api/books` | 一覧に含めない |
| `DELETE /api/books/:id` | すでに削除済みなら `404 Not Found` |
| `POST /api/books/:book_id/notes` | `404 Not Found` |
| `DELETE /api/books/:book_id/notes/:id` | `404 Not Found` |
| `POST /api/books/:book_id/notes/bulk` | `404 Not Found` |
| `GET /api/books/:book_id/notes_search` | `404 Not Found` |

---

## DB / Rails の整合

Bookは論理削除するため、通常のAPI削除では物理削除を行わない。

一方で、DBレベルでは参照整合性を守るため、外部キー制約を維持する。

- `books.user_id -> users.id`
- `notes.book_id -> books.id`
- `ON DELETE RESTRICT`

Railsの関連でも、物理削除cascadeは使わない。

```ruby
class Book < ApplicationRecord
  belongs_to :user
  has_many :notes
end
```

`dependent: :destroy` は使わない。  
通常の削除は `deleted_at` の更新で表現する。

---

## Scope方針

`default_scope` は使用しない。

理由は、暗黙条件によって以下のリスクがあるため。

- 管理用途や調査用途で削除済みBookを確認しづらくなる
- クエリ条件が見えにくくなる
- specやdebug時に意図しない除外が起きる

通常APIでは、明示的に `alive` scope を使う。

```ruby
scope :alive, -> { where(deleted_at: nil) }
```

---

## 例外的に削除済みBookを参照するケース

通常のAPIでは、削除済みBookは参照しない。

ただし、将来的に以下の用途では削除済みBookを参照する可能性がある。

- 管理画面
- 復元処理
- 監査ログ
- 運用調査

これらは通常のユーザー向けAPIとは分離して扱う。

---

## まとめ

Bookの削除は `deleted_at` による論理削除とする。

通常APIでは、削除済みBookを「存在しないもの」として扱い、  
Controller入口で `current_user.books.alive.find(...)` により、  
所有者境界とalive確認を同時に行う。

Serviceには確認済みBookを渡し、処理本体に責務を集中させる。