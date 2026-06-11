# Bulk Create Notes API Contract

## 0. Purpose

`POST /api/books/:book_id/notes/bulk` は、1つのBookに対して複数のNoteを一括作成するためのAPIである。

読書中の連続メモ入力では、複数の引用メモをまとめて保存したいケースがある。  
このAPIでは、1リクエストを1つの論理的な書き込み単位として扱い、全件成功または全件失敗のどちらかに統一する。

部分的に保存される中途半端な状態は許容しない。

---

## 1. Endpoint

```http
POST /api/books/:book_id/notes/bulk
```

---

## 2. Authentication

このAPIは Bearer Token 認証を必要とする。

```http
Authorization: Bearer <token>
```

未認証、無効Token、期限切れToken、revoked Token の場合は `401 Unauthorized` を返す。

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

---

## 3. Ownership Boundary

このAPIでは、Controller側で以下の条件を満たすBookのみを対象にする。

- ログイン中ユーザーが所有していること
- `deleted_at` が `nil` であること

実装上は、Book取得を以下の境界で行う。

```ruby
current_user.books.alive.find(params[:book_id])
```

そのため、以下の場合はすべて `404 Not Found` として扱う。

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

これは、リソースの存在有無や所有関係を外部に露出しないためである。

---

## 4. Request

### Path Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `book_id` | integer | Yes | 対象BookのID |

### Request Body

```json
{
  "notes": [
    {
      "page": 12,
      "quote": "引用文1",
      "memo": "メモ1"
    },
    {
      "page": 13,
      "quote": "引用文2",
      "memo": null
    }
  ]
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `notes` | array | Yes | Noteオブジェクトの配列 |
| `notes[].page` | integer | Yes | ページ番号。1以上 |
| `notes[].quote` | string | Yes | 引用文。最大1000文字 |
| `notes[].memo` | string / null | No | メモ。最大2000文字 |

---

## 5. Validation Rules

### `notes`

- 必須
- 配列であること
- 各要素はNoteオブジェクトであること

`notes` が存在しない、配列でない、または要素がオブジェクトでない場合は `400 Bad Request` を返す。

```json
{
  "error": {
    "code": "bad_request",
    "message": "Bad request"
  }
}
```

### `notes[].page`

- 必須
- integer
- 1以上

### `notes[].quote`

- 必須
- 空文字は不可
- 最大1000文字

### `notes[].memo`

- 任意
- `null` 可
- 最大2000文字

---

## 6. Success Response

全件validな場合、すべてのNoteを作成し、`201 Created` を返す。

**201 Created**

```json
{
  "notes": [
    {
      "id": 101,
      "page": 12,
      "quote": "引用文1",
      "memo": "メモ1",
      "created_at": "2026-06-11T04:00:14.239Z"
    },
    {
      "id": 102,
      "page": 13,
      "quote": "引用文2",
      "memo": null,
      "created_at": "2026-06-11T04:00:14.670Z"
    }
  ],
  "meta": {
    "created_count": 2
  }
}
```

### Response Fields

| Field | Type | Description |
|-------|------|-------------|
| `notes` | array | 作成されたNote一覧 |
| `notes[].id` | integer | Note ID |
| `notes[].page` | integer | ページ番号 |
| `notes[].quote` | string | 引用文 |
| `notes[].memo` | string / null | メモ |
| `notes[].created_at` | string | 作成日時 |
| `meta.created_count` | integer | 作成件数 |

---

## 7. Error Responses

### 400 Bad Request

リクエスト構造が不正な場合。

例：

- `notes` が存在しない
- `notes` が配列でない
- `notes` の要素がオブジェクトでない

```json
{
  "error": {
    "code": "bad_request",
    "message": "Bad request"
  }
}
```

---

### 401 Unauthorized

認証に失敗した場合。

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

---

### 404 Not Found

対象Bookが存在しない、削除済み、またはログイン中ユーザーの所有Bookではない場合。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

---

### 422 Unprocessable Entity

1件以上のNoteがvalidationに失敗した場合。  
この場合、DBには1件も作成されない。

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

| Field | Type | Description |
|-------|------|-------------|
| `details[].index` | integer | エラーが発生した `notes` 配列のインデックス。0始まり |
| `details[].messages` | string[] | そのNoteに対するvalidation error |

---

## 8. Transaction Boundary

このAPIは、1 HTTP requestを1つの論理的な書き込み単位として扱う。

### Invariant

- 全件validな場合のみ保存する
- 1件でもinvalidな場合は全件保存しない
- 部分成功は禁止
- 422が返る場合、DBには1件も作成されない

```text
valid notes only
→ 201 Created
→ all notes are saved

one or more invalid notes
→ 422 Unprocessable Entity
→ no notes are saved
```

---

## 9. DB Constraints

このAPIは、Rails側validationに加えてDB制約によって整合性を担保する。

| Table | Column | Constraint |
|-------|--------|------------|
| `notes` | `book_id` | NOT NULL / FK |
| `notes` | `page` | NOT NULL / CHECK `page >= 1` |
| `notes` | `quote` | NOT NULL / CHECK `char_length(quote) <= 1000` |
| `notes` | `memo` | CHECK `memo IS NULL OR char_length(memo) <= 2000` |

`notes.book_id → books.id` は `ON DELETE RESTRICT` とし、物理削除時の参照整合性をDBレベルで守る。

なお、MVPでは `(book_id, page, quote)` に対するunique制約は設定しない。  
同じページ・同じ引用を重複して残したいケースも考えられるためである。

---

## 10. 本番確認済み挙動

本番環境で以下を確認済み。

- 正常系
  - `POST /api/books/:book_id/notes/bulk`
  - `201 Created`
  - `meta.created_count: 3`

- 一部invalid
  - `422 Unprocessable Entity`
  - `details` に `index` と `messages` を返す
  - 同一indexに複数のエラーメッセージが入る
  - DBには1件も作成されない

- 他ユーザーBookへのBulk Create
  - `404 Not Found`
  - 所有権情報を露出しない

---