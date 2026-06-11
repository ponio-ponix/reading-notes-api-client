# Invariants

## 目的

本ドキュメントは、Reading Notes Backend API における「壊れてはならない前提条件」を定義する。

不変条件は、個別ユースケースよりも長寿命な設計ルールであり、  
DB制約・Model validation・Controller境界・Service処理・APIレスポンスの整合性を支える。

APIレスポンス形式の最終定義は [`docs/40_api/api_overview.md`](../40_api/api_overview.md) を参照する。  
DB制約の詳細は [`docs/30_architecture/db_constraints.md`](./db_constraints.md) を参照する。

---

## 1. Model-Level Invariants

### 1.1 Book title is required

Book は必ず `title` を持つ。

- `books.title` は `NULL` 不可
- 空文字は許容しない
- Model validation でも `presence: true` を確認する

**Why**

Book title は書籍を識別する最低限の情報であり、省略を許可しない。

---

### 1.2 Book belongs to User

Book は必ず User に属する。

- `books.user_id` は `NULL` 不可
- `books.user_id` は `users.id` への外部キー
- Book取得はログイン中ユーザーの所有範囲から行う

**Why**

Book はユーザーごとのデータ境界であり、所有者を持たないBookを許可しない。

---

### 1.3 AccessToken belongs to User

AccessToken は必ず User に属する。

- `access_tokens.user_id` は `NULL` 不可
- `access_tokens.user_id` は `users.id` への外部キー
- `token_digest` は `NULL` 不可かつ一意
- raw token はDBに保存しない
- token は `expires_at` と `revoked_at` により有効性を判断する

**Why**

Bearer Token 認証では、tokenの漏えい耐性と失効管理が必要になる。  
DBには raw token ではなく digest のみを保存することで、DB漏えい時のリスクを下げる。

---

### 1.4 Note belongs to Book

Note は必ず Book に属する。

- `notes.book_id` は `NULL` 不可
- `notes.book_id` は `books.id` への外部キー
- 存在しないBookを参照するNoteは保存できない

**Why**

Note はBookに紐づく引用メモであり、孤立したNoteを許可しない。

---

### 1.5 Note page is required and must be greater than or equal to 1

Note の `page` は必須であり、1以上である。

- `notes.page` は `NULL` 不可
- `page >= 1`
- DB CHECK制約とModel validationで保証する

**Why**

引用位置はNoteの基本属性であり、0や負数のページを保存させない。

---

### 1.6 Note quote is required

Note の `quote` は必須である。

- `notes.quote` は `NULL` 不可
- 空文字は許容しない
- 最大1000文字

**Why**

引用文が存在しないNoteは、読書引用メモとして意味を持たない。  
また、過剰な長文によるDB肥大化を防ぐ。

---

### 1.7 Note memo is optional but length-limited

Note の `memo` は任意である。

- `NULL` 許容
- 最大2000文字

**Why**

補足メモは任意入力として許可しつつ、無制限入力による肥大化を防ぐ。

---

## 2. Ownership and Soft Delete Invariants

### 2.1 User can access only own Books

Book / Note 関連APIでは、ログイン中ユーザーが所有するBookだけを対象にする。

Book ID を受け取るAPIでは、Controller入口で以下を確認する。

```ruby
current_user.books.alive.find(params[:book_id])
```

これにより、以下を同時に確認する。

- 認証済みユーザーであること
- ログイン中ユーザーが所有するBookであること
- Bookが削除済みではないこと

**Why**

所有者境界をController入口で統一することで、他ユーザーのBook / Noteを参照・操作できないようにする。

---

### 2.2 Deleted Book is treated as not found

`deleted_at` が設定されたBookは、通常APIでは存在しないものとして扱う。

以下の場合はすべて `404 Not Found` を返す。

- Bookが存在しない
- Bookが削除済み
- Bookが他ユーザー所有

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

**Why**

存在しない場合、削除済みの場合、他ユーザー所有の場合を区別しないことで、  
リソースの存在有無や所有関係を外部に露出しない。

---

### 2.3 Book deletion is logical deletion

Book削除は物理削除ではなく、`deleted_at` の更新で表現する。

- `DELETE /api/books/:id` は `deleted_at` を更新する
- `GET /api/books` は削除済みBookを返さない
- Notes系APIは削除済みBookを対象にしない
- 物理削除によるcascadeは行わない

**Why**

Book削除後も参照整合性を保ち、必要に応じて将来的な復元・監査・運用調査に対応できる余地を残す。

---

## 3. Bulk Create Invariants

### 3.1 One request is one transaction

`POST /api/books/:book_id/notes/bulk` は、1 HTTP request を1つの論理的な書き込み単位として扱う。

- Bulk作成処理は transaction 内で実行する
- transaction boundary は notes の一括insert全体

**Why**

複数Noteの一括保存では、途中まで保存された状態を許容しないため。

---

### 3.2 All-or-nothing

Bulk Create は全件成功または全件失敗のどちらかである。

- すべてvalidな場合のみ保存する
- 1件でもinvalidなNoteがあれば全件rollbackする
- 部分成功は禁止する

```text
all notes valid
→ 201 Created
→ all notes are saved

one or more notes invalid
→ 422 Unprocessable Entity
→ no notes are saved
```

**Why**

連続メモ入力では、一部だけ保存される状態はユーザー体験とデータ整合性の両方を壊す。

---

### 3.3 Bulk error identifies failed input index

Bulk Create の `422 Unprocessable Entity` では、どの入力行がinvalidだったかを `details` に含める。

```json
{
  "error": {
    "code": "unprocessable_entity",
    "message": "Validation failed",
    "details": [
      {
        "index": 1,
        "messages": [
          "Quote can't be blank",
          "Page must be greater than or equal to 1"
        ]
      }
    ]
  }
}
```

**Why**

部分成功を禁止しつつ、クライアント側ではどの入力行を修正すべきか判断できる必要がある。

---

## 4. Search Invariants

### 4.1 Search target is limited to confirmed Book

`GET /api/books/:book_id/notes_search` は、Controller入口で確認済みのBookに紐づくNoteだけを検索対象にする。

```ruby
book = current_user.books.alive.find(params[:book_id])
```

検索対象は常に以下に限定する。

- ログイン中ユーザーが所有するBook
- 削除済みではないBook
- 指定Bookに紐づくNote

**Why**

検索APIでも、所有者境界とsoft delete境界を必ず維持するため。

---

### 4.2 Page range search is inclusive

`page_from` / `page_to` によるページ範囲検索は閉区間である。

```text
page_from=10, page_to=20
→ page >= 10 AND page <= 20
```

**Why**

ユーザーが指定した範囲の開始ページと終了ページを含める方が自然である。

---

### 4.3 Search result order is stable

検索結果は常に `created_at DESC` で返す。

```ruby
order(created_at: :desc)
```

**Why**

読書メモは新しく追加したものから確認することが多く、UI表示順とAPIレスポンス順を一致させるため。

---

### 4.4 Empty result is not an error

検索条件に一致するNoteが存在しない場合でも、`200 OK` を返す。

```json
{
  "notes": [],
  "meta": {
    "total_count": 0,
    "page": 1,
    "limit": 10,
    "total_pages": 0
  }
}
```

**Why**

検索結果が0件であることは正常な検索結果であり、APIエラーではないため。

---

## 5. Error Handling Invariants

### 5.1 Error response shape is unified

エラーレスポンスは、原則として以下の形式に統一する。

```json
{
  "error": {
    "code": "error_code",
    "message": "error message"
  }
}
```

詳細が必要な場合のみ `details` を含める。

```json
{
  "error": {
    "code": "unprocessable_entity",
    "message": "Validation failed",
    "details": [
      "Title can't be blank"
    ]
  }
}
```

**Why**

API全体でエラー形式を統一することで、クライアント側のエラー処理を単純にする。

---

### 5.2 4xx and 5xx are separated

本APIでは、4xxと5xxを以下の基準で分ける。

- 4xx
  - クライアントのリクエスト内容に問題がある
  - アプリ側が意図して検出した失敗

- 5xx
  - サーバ側の想定外エラー
  - 実装バグや未考慮ケースとして検知すべき失敗

**Why**

入力エラーとサーバ側バグを混同すると、運用時の調査・デバッグが難しくなるため。

---

## 6. Responsibility Invariants

### 6.1 Controller owns HTTP boundary

Controller はHTTP境界の処理を担当する。

- 認証
- 所有者境界
- alive Book確認
- request parameterの構造確認
- response rendering

**Why**

HTTPリクエストに依存する責務をControllerに集約することで、Serviceの責務を処理本体に集中させる。

---

### 6.2 Service owns use case processing

Service は処理本体を担当する。

- Bulk Create の一括作成
- Bulk Create のtransaction boundary
- Search条件の適用
- 必要なドメイン処理

Serviceには、Controllerで確認済みのBookを渡す。

**Why**

Controllerで境界を確定し、Serviceでは確認済み入力を前提に処理本体へ集中するため。

---

## 7. Future Extension Invariants

### 7.1 Note remains the minimum quote unit

Note は「引用メモの最小単位」として扱う。

タグ・章・カテゴリなどは、将来的に外部テーブルで表現する。  
Note自体に過剰な責務を持たせない。

---

### 7.2 Book remains the group boundary for Notes

Book はNoteの最小グループ境界である。

共有機能や共同編集機能を追加する場合でも、NoteはBookを通じて管理する。

---

## まとめ

本APIでは、以下の不変条件を守る。

- Book / Note / AccessToken のDB整合性
- ログイン中ユーザーごとの所有者境界
- Bookの論理削除
- Bulk Create の all-or-nothing
- Search対象のBook内限定
- 共通エラーレスポンス形式
- Controller / Service の責務分離

これらにより、認証・所有権・DB制約・トランザクション・検索結果の一貫性を保証する。