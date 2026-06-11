# Reading Notes Backend API 仕様

> 📌 Docs Policy  
> 本APIドキュメントは、Reading Notes Backend API の契約仕様です。  
> 主要エンドポイント、認証方式、HTTPステータス、エラーレスポンス形式を定義します。  
> 実装アウトラインや設計方針との役割分担については  
> 👉 [`docs/99_meta/docs_policy.md`](../99_meta/docs_policy.md) を参照してください。

---

## 0. 設計の目的

Reading Notes Backend API は、読書メモを管理するためのバックエンドAPIです。

単なるCRUDだけでなく、以下を意識して設計しています。

- Bearer Token 認証
- ログイン中ユーザーごとの所有権境界
- Book の論理削除
- DB制約とRails側バリデーションによる整合性担保
- Controller / Service の責務分離
- 共通エラーレスポンス形式の統一
- RSpec による認証・所有権・異常系の確認

Book ID を受け取る Notes 系 API では、Controller 側で認証・所有権・未削除Bookであることを確認し、Service 層には確認済みの Book を渡します。  
これにより、Controller はHTTP境界の確認、Service は処理本体に責務を集中させます。

---

## 1. 共通仕様

- Base URL: `/api`
- Format: JSON
- Header:
  - `Content-Type: application/json`
  - `Authorization: Bearer <token>`

原則として `/api` 配下のAPIは Bearer Token 認証を必要とします。  
例外として、以下のエンドポイントは認証不要です。

- `POST /api/users`
- `POST /api/auth/session`

---

### 1.1 認証仕様

本APIでは Bearer Token 認証を使用します。

`POST /api/auth/session` でログインすると、生のAccess Tokenを返します。  
サーバ側ではTokenを平文保存せず、SHA256でdigest化した `token_digest` を保存します。

認証が必要なAPIでは、以下のHeaderを付与します。

```http
Authorization: Bearer <token>
```

Tokenは以下の条件を満たす場合のみ有効です。

- `revoked_at` が `nil`
- `expires_at` が現在時刻より後

Tokenなし、Bearer形式でないHeader、空Token、無効Token、期限切れToken、revoked Token の場合は `401 Unauthorized` を返します。

---

### 1.2 所有権境界

Book / Note 関連APIでは、ログイン中ユーザーが所有するデータのみを対象とします。

Book ID を受け取るAPIでは、Controller側で以下の条件を満たすBookを取得します。

- ログイン中ユーザーが所有していること
- `deleted_at` が `nil` であること

Bookが存在しない、削除済み、または他ユーザー所有の場合は `404 Not Found` として扱います。  
これはリソースの存在有無や所有関係を外部に露出しないためです。

---

### 1.3 共通エラーレスポンス形式

失敗時は、原則として以下の形式を返します。

```json
{
  "error": {
    "code": "error_code",
    "message": "error message"
  }
}
```

詳細情報がある場合は `details` を含めます。

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

---

### 1.4 ステータスコードの基本方針

#### 400 Bad Request

リクエスト形式が不正な場合。

例：

- 期待するJSON構造でない
- 必須パラメータが欠落している
- 配列であるべき値が配列でない
- クエリパラメータの型が不正

```json
{
  "error": {
    "code": "bad_request",
    "message": "Bad request"
  }
}
```

---

#### 401 Unauthorized

認証が必要なAPIで、Tokenがない、またはTokenが無効な場合。

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

---

#### 404 Not Found

対象リソースが存在しない、またはログイン中ユーザーがアクセス可能な範囲に存在しない場合。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

---

#### 422 Unprocessable Entity

リクエスト形式は正しいが、モデルバリデーションまたはDB制約に違反した場合。

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

DB制約違反の場合。

```json
{
  "error": {
    "code": "db_constraint_violation",
    "message": "DB constraint violated"
  }
}
```

---

#### 500 Internal Server Error

本番環境でサーバ側の想定外エラーが発生した場合。

```json
{
  "error": {
    "code": "internal_server_error",
    "message": "Internal server error"
  }
}
```

---

### 1.5 Bulk API 固有の422形式

Bulk Create では、「どの要素が失敗したか」を `details` に含めます。  
同一indexに複数のエラーメッセージが入る場合があります。

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
| `details[].messages` | string[] | そのインデックスで発生したバリデーションエラーメッセージ |

---

## 2. Endpoints

---

### 2.1 Health

#### GET /healthz

アプリケーションの稼働確認用エンドポイントです。

##### Response

**200 OK**

```json
{
  "ok": true
}
```

---

### 2.2 Users

#### POST /api/users

ユーザーを作成します。  
このエンドポイントは認証不要です。

##### Request

```json
{
  "user": {
    "name": "Taro",
    "email": "user@example.com",
    "password": "password",
    "password_confirmation": "password"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | No | ユーザー名 |
| `email` | string | Yes | メールアドレス。一意制約あり |
| `password` | string | Yes | パスワード |
| `password_confirmation` | string | No | パスワード確認 |

##### Response

**201 Created**

```json
{
  "id": 1,
  "name": "Taro",
  "email": "user@example.com"
}
```

##### Error

**422 Unprocessable Entity**

```json
{
  "error": {
    "code": "unprocessable_entity",
    "message": "Validation failed",
    "details": [
      "Email has already been taken"
    ]
  }
}
```

---

### 2.3 Auth

#### POST /api/auth/session

ログインし、Bearer Tokenを発行します。  
このエンドポイントは認証不要です。

##### Request

```json
{
  "email": "user@example.com",
  "password": "password"
}
```

##### Response

**200 OK**

```json
{
  "token": "<token>"
}
```

##### Error

**401 Unauthorized**

email / password が空、または認証に失敗した場合。

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

---

#### DELETE /api/auth/session

現在のBearer Tokenをrevoked状態にし、ログアウトします。

##### Header

```http
Authorization: Bearer <token>
```

##### Response

**200 OK**

```json
{
  "ok": true
}
```

##### Error

**401 Unauthorized**

Tokenがない、無効、期限切れ、またはrevoked済みの場合。

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

---

### 2.4 Books

#### GET /api/books

ログイン中ユーザーが所有する未削除Book一覧を取得します。  
削除済みBookは含まれません。

##### Header

```http
Authorization: Bearer <token>
```

##### Response

**200 OK**

```json
[
  {
    "id": 1,
    "title": "リーダブルコード",
    "author": "Dustin Boswell"
  },
  {
    "id": 2,
    "title": "プログラマが知るべき97のこと",
    "author": "Kevlin Henney"
  }
]
```

- 配列は `created_at` 降順でソートされます
- Bookが存在しない場合は空配列 `[]` を返します

##### Error

**401 Unauthorized**

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

---

#### POST /api/books

ログイン中ユーザーに紐づくBookを作成します。

##### Header

```http
Authorization: Bearer <token>
```

##### Request

```json
{
  "book": {
    "title": "リーダブルコード",
    "author": "Dustin Boswell"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `title` | string | Yes | 書籍タイトル |
| `author` | string | No | 著者名 |

##### Response

**201 Created**

```json
{
  "id": 1,
  "title": "リーダブルコード",
  "author": "Dustin Boswell"
}
```

##### Error

**401 Unauthorized**

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

**422 Unprocessable Entity**

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

---

#### DELETE /api/books/:id

ログイン中ユーザーが所有する未削除Bookを論理削除します。  
物理削除ではなく、`deleted_at` を現在時刻で更新します。

##### Header

```http
Authorization: Bearer <token>
```

##### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `id` | integer | Book の ID |

##### Response

**204 No Content**

レスポンスボディなし。

##### Error

**401 Unauthorized**

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

**404 Not Found**

Bookが存在しない、削除済み、またはログイン中ユーザーの所有Bookではない場合。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

---

### 2.5 Notes

#### POST /api/books/:book_id/notes

ログイン中ユーザーが所有する未削除BookにNoteを1件作成します。

##### Header

```http
Authorization: Bearer <token>
```

##### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `book_id` | integer | Book の ID |

##### Request

```json
{
  "note": {
    "page": 42,
    "quote": "コードは他の人が最短時間で理解できるように書かなければいけない",
    "memo": "チーム開発で重要な原則"
  }
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `page` | integer | Yes | ページ番号。1以上 |
| `quote` | string | Yes | 引用文。最大1000文字 |
| `memo` | string | No | メモ。最大2000文字 |

##### Response

**201 Created**

```json
{
  "id": 1,
  "book_id": 1,
  "page": 42,
  "quote": "コードは他の人が最短時間で理解できるように書かなければいけない",
  "memo": "チーム開発で重要な原則",
  "created_at": "2024-01-15T10:30:00.000Z"
}
```

##### Error

**401 Unauthorized**

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

**404 Not Found**

Bookが存在しない、削除済み、またはログイン中ユーザーの所有Bookではない場合。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

**422 Unprocessable Entity**

Noteのバリデーションに失敗した場合。

```json
{
  "error": {
    "code": "unprocessable_entity",
    "message": "Validation failed",
    "details": [
      "Quote can't be blank"
    ]
  }
}
```

---

#### DELETE /api/books/:book_id/notes/:id

ログイン中ユーザーが所有する未削除Bookに紐づくNoteを削除します。

##### Header

```http
Authorization: Bearer <token>
```

##### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `book_id` | integer | Book の ID |
| `id` | integer | Note の ID |

##### Response

**204 No Content**

レスポンスボディなし。

##### Error

**401 Unauthorized**

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

**404 Not Found**

Bookが存在しない、削除済み、他ユーザー所有、または指定NoteがそのBookに存在しない場合。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

---

### 2.6 Notes Bulk Create

#### POST /api/books/:book_id/notes/bulk

ログイン中ユーザーが所有する未削除Bookに、複数のNoteを一括作成します。  
全件成功 or 全件失敗のトランザクションとして扱います。

##### Header

```http
Authorization: Bearer <token>
```

##### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `book_id` | integer | Book の ID |

##### Request

```json
{
  "notes": [
    {
      "page": 10,
      "quote": "引用文1",
      "memo": "メモ1"
    },
    {
      "page": 20,
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
| `notes[].memo` | string | No | メモ。最大2000文字 |

##### Response

**201 Created**

```json
{
  "notes": [
    {
      "id": 1,
      "page": 10,
      "quote": "引用文1",
      "memo": "メモ1",
      "created_at": "2024-01-15T10:30:00.000Z"
    },
    {
      "id": 2,
      "page": 20,
      "quote": "引用文2",
      "memo": null,
      "created_at": "2024-01-15T10:30:00.000Z"
    }
  ],
  "meta": {
    "created_count": 2
  }
}
```

##### Error

**400 Bad Request**

リクエスト構造が不正な場合。

```json
{
  "error": {
    "code": "bad_request",
    "message": "Bad request"
  }
}
```

**401 Unauthorized**

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

**404 Not Found**

Bookが存在しない、削除済み、またはログイン中ユーザーの所有Bookではない場合。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

**422 Unprocessable Entity**

1件以上のバリデーションエラーがある場合。  
この場合、DBには1件も作成されません。

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

---

### 2.7 Notes Search

#### GET /api/books/:book_id/notes_search

ログイン中ユーザーが所有する未削除BookのNoteを検索・フィルタリング・ページネーションして取得します。

##### Header

```http
Authorization: Bearer <token>
```

##### Path Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `book_id` | integer | Book の ID |

##### Query Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `q` | string | No | — | 検索キーワード。quote または memo に部分一致。スペース区切りでAND検索 |
| `page_from` | integer | No | — | ページ番号の下限 |
| `page_to` | integer | No | — | ページ番号の上限 |
| `page` | integer | No | 1 | ページネーションのページ番号 |
| `limit` | integer | No | 50 | 1ページあたりの件数。最大200 |

##### Response

**200 OK**

```json
{
  "notes": [
    {
      "id": 1,
      "book_id": 1,
      "page": 42,
      "quote": "コードは他の人が最短時間で理解できるように書かなければいけない",
      "memo": "チーム開発で重要な原則",
      "created_at": "2024-01-15T10:30:00.000Z"
    }
  ],
  "meta": {
    "total_count": 15,
    "page": 1,
    "limit": 50,
    "total_pages": 1
  }
}
```

検索条件に一致するNoteが存在しない場合は、`200 OK` で `notes: []` を返します。

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

| Field | Type | Description |
|-------|------|-------------|
| `notes` | array | Noteオブジェクトの配列 |
| `meta.total_count` | integer | フィルタ条件に合致する全件数 |
| `meta.page` | integer | 現在のページ番号 |
| `meta.limit` | integer | 1ページあたりの件数 |
| `meta.total_pages` | integer | 総ページ数 |

##### Error

**400 Bad Request**

クエリパラメータが不正な場合。

```json
{
  "error": {
    "code": "bad_request",
    "message": "Bad request"
  }
}
```

**401 Unauthorized**

```json
{
  "error": {
    "code": "unauthorized",
    "message": "Authentication required"
  }
}
```

**404 Not Found**

Bookが存在しない、削除済み、またはログイン中ユーザーの所有Bookではない場合。

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

---

## 3. DB制約とRails側制御

本APIでは、Rails側のバリデーションに加えて、DB制約でもデータ整合性を担保します。

主なDB制約は以下です。

| Table | Column | Constraint |
|-------|--------|------------|
| `users` | `email` | NOT NULL / UNIQUE |
| `users` | `password_digest` | NOT NULL |
| `access_tokens` | `user_id` | NOT NULL / FK |
| `access_tokens` | `token_digest` | NOT NULL / UNIQUE |
| `access_tokens` | `expires_at` | NOT NULL |
| `books` | `title` | NOT NULL |
| `books` | `user_id` | NOT NULL / FK |
| `notes` | `book_id` | NOT NULL / FK |
| `notes` | `page` | NOT NULL / CHECK `page >= 1` |
| `notes` | `quote` | NOT NULL / CHECK `char_length(quote) <= 1000` |
| `notes` | `memo` | CHECK `memo IS NULL OR char_length(memo) <= 2000` |

DB制約違反は `422 Unprocessable Entity` として扱います。

```json
{
  "error": {
    "code": "db_constraint_violation",
    "message": "DB constraint violated"
  }
}
```

---

## 4. 本番確認済みフロー

以下は、本番環境で確認済みの代表的な認証付きAPI操作フローです。

---

### 4.0 実行用Base URL

```bash

BASE_URL="https://backend-withered-voice-4962.fly.dev"

```

Health Check:

```bash

curl "$BASE_URL/healthz"

```

期待値:

```json

{

  "ok": true

}

```

---

### 4.1 Quick Evaluation Route

本番環境で最小限の動作確認を行う場合は、以下の順で確認できます。

1. `GET /healthz`

2. `POST /api/users`

3. `POST /api/auth/session`

4. `GET /api/books` with Bearer Token

5. `POST /api/books` with Bearer Token

6. `DELETE /api/books/:id` with Bearer Token

詳細なリクエスト・レスポンス例は、次の `Book操作` セクションを参照してください。

---

### 4.2 Book操作

#### 1. ログイン / Token発行

`POST /api/auth/session`

**200 OK**

```json
{
  "token": "<token>"
}
```

---

#### 2. Bearer Token付きでBook一覧取得

`GET /api/books`

Header:

```http
Authorization: Bearer <token>
```

**200 OK**

```json
[]
```

---

#### 3. Bearer Token付きでBook作成

`POST /api/books`

Header:

```http
Authorization: Bearer <token>
```

Request:

```json
{
  "book": {
    "title": "Clean Architecture",
    "author": "Robert C. Martin"
  }
}
```

**201 Created**

```json
{
  "id": 8,
  "title": "Clean Architecture",
  "author": "Robert C. Martin"
}
```

---

#### 4. 作成したBookが一覧に含まれることを確認

`GET /api/books`

Header:

```http
Authorization: Bearer <token>
```

**200 OK**

```json
[
  {
    "id": 8,
    "title": "Clean Architecture",
    "author": "Robert C. Martin"
  }
]
```

---

#### 5. Bookを論理削除

`DELETE /api/books/:id`

Header:

```http
Authorization: Bearer <token>
```

**204 No Content**

レスポンスボディなし。

---

#### 6. 削除後、Book一覧から除外されることを確認

`GET /api/books`

Header:

```http
Authorization: Bearer <token>
```

**200 OK**

```json
[]
```

---

### 4.3 Bulk / Search / 所有権境界

以下は、本番環境で確認済みの代表的なBulk作成・検索・所有権境界確認フローです。

#### Bulk Create 正常系

`POST /api/books/:book_id/notes/bulk`

**201 Created**

```json
{
  "notes": [
    {
      "id": 19,
      "page": 10,
      "quote": "Clean Architecture emphasizes boundaries.",
      "memo": "architecture memo",
      "created_at": "2026-06-11T04:00:14.239Z"
    },
    {
      "id": 20,
      "page": 20,
      "quote": "Ruby on Rails makes API development productive.",
      "memo": "rails memo",
      "created_at": "2026-06-11T04:00:14.670Z"
    },
    {
      "id": 21,
      "page": 30,
      "quote": "Search behavior should be verified by curl.",
      "memo": "search memo",
      "created_at": "2026-06-11T04:00:14.879Z"
    }
  ],
  "meta": {
    "created_count": 3
  }
}
```

---

#### Search 正常系：キーワード検索

`GET /api/books/:book_id/notes_search?q=Rails&page=1&limit=10`

**200 OK**

```json
{
  "notes": [
    {
      "id": 20,
      "book_id": 21,
      "page": 20,
      "quote": "Ruby on Rails makes API development productive.",
      "memo": "rails memo",
      "created_at": "2026-06-11T04:00:14.670Z"
    }
  ],
  "meta": {
    "total_count": 1,
    "page": 1,
    "limit": 10,
    "total_pages": 1
  }
}
```

---

#### Search 正常系：ページ範囲検索

`GET /api/books/:book_id/notes_search?page_from=10&page_to=20&page=1&limit=10`

**200 OK**

```json
{
  "notes": [
    {
      "id": 20,
      "book_id": 21,
      "page": 20,
      "quote": "Ruby on Rails makes API development productive.",
      "memo": "rails memo",
      "created_at": "2026-06-11T04:00:14.670Z"
    },
    {
      "id": 19,
      "book_id": 21,
      "page": 10,
      "quote": "Clean Architecture emphasizes boundaries.",
      "memo": "architecture memo",
      "created_at": "2026-06-11T04:00:14.239Z"
    }
  ],
  "meta": {
    "total_count": 2,
    "page": 1,
    "limit": 10,
    "total_pages": 1
  }
}
```

---

#### Search 正常系：該当なし

`GET /api/books/:book_id/notes_search?q=nonexistentkeyword&page=1&limit=10`

**200 OK**

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

---

#### Bulk Create 異常系：一部invalid

`POST /api/books/:book_id/notes/bulk`

**422 Unprocessable Entity**

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

この場合、全件成功 or 全件失敗のトランザクションとして扱い、DBには1件も作成されません。

---

#### Search 異常系：不正なクエリパラメータ

`GET /api/books/:book_id/notes_search?page=abc&limit=10`

**400 Bad Request**

```json
{
  "error": {
    "code": "bad_request",
    "message": "Bad request"
  }
}
```

---

#### 所有権境界：他ユーザーBookへのSearch

他ユーザーが所有するBook IDを指定して、元ユーザーのTokenで検索します。

`GET /api/books/:other_user_book_id/notes_search?q=Rails&page=1&limit=10`

**404 Not Found**

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```

---

#### 所有権境界：他ユーザーBookへのBulk Create

他ユーザーが所有するBook IDを指定して、元ユーザーのTokenでBulk作成します。

`POST /api/books/:other_user_book_id/notes/bulk`

**404 Not Found**

```json
{
  "error": {
    "code": "not_found",
    "message": "Resource not found"
  }
}
```