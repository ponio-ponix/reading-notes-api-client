# Search Notes API Contract
## 0. Purpose
`GET /api/books/:book_id/notes_search` は、指定したBookに紐づくNoteを検索・フィルタリング・ページネーションして取得するAPIである。
構造化された読書メモ検索の中核として、以下の条件でNoteを取得できるようにする。
- キーワード検索
- ページ範囲検索
- ページネーション
---
## 1. Endpoint
```http
GET /api/books/:book_id/notes_search
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
### Query Parameters
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `q` | string | No | — | `quote` または `memo` に対する部分一致キーワード |
| `page_from` | integer | No | — | ページ番号の下限 |
| `page_to` | integer | No | — | ページ番号の上限 |
| `page` | integer | No | `1` | ページネーションのページ番号 |
| `limit` | integer | No | `50` | 1ページあたりの件数。最大 `200` |
---
## 5. Query Parameter Rules
### 5.1 `q`
`q` が指定された場合、`quote` / `memo` に対して部分一致検索を行う。
- `quote` または `memo` に一致するNoteを返す
- 大文字・小文字を区別しない検索を想定する
- スペース区切りの場合、AND検索として扱う
- `q` が未指定または空文字相当の場合は、キーワード検索を適用しない
例：
| `q` | Meaning |
|-----|---------|
| `Rails` | `quote` または `memo` に `Rails` を含むNote |
| `Clean Architecture` | `Clean` と `Architecture` の両方に一致するNote |
| 空文字 | キーワード検索なし |
---
### 5.2 `page_from` / `page_to`
ページ番号による範囲検索を行う。
- `page_from` のみ指定された場合: `page >= page_from`
- `page_to` のみ指定された場合: `page <= page_to`
- 両方指定された場合: `page_from <= page <= page_to`
`page_from` / `page_to` が数値として扱えない場合、または不正な範囲指定の場合は `400 Bad Request` を返す。
---
### 5.3 `page` / `limit`
ページネーションに使用する。
- `page` 未指定時は `1`
- `limit` 未指定時は `50`
- `limit` の最大値は `200`
- 数値として扱えない値が指定された場合は `400 Bad Request` を返す
---
## 6. Sort Order
検索結果は `created_at DESC` で返す。
```ruby
order(created_at: :desc)
```
---
## 7. Success Response
### 200 OK
```json
{
  "notes": [
    {
      "id": 5,
      "book_id": 1,
      "page": 10,
      "quote": "人間は耐えることができるのだ。",
      "memo": "テスト用",
      "created_at": "2026-06-11T04:00:14.670Z"
    }
  ],
  "meta": {
    "total_count": 5,
    "page": 1,
    "limit": 20,
    "total_pages": 1
  }
}
```
### Response Fields
| Field | Type | Description |
|-------|------|-------------|
| `notes` | array | Noteオブジェクトの配列 |
| `notes[].id` | integer | Note ID |
| `notes[].book_id` | integer | Book ID |
| `notes[].page` | integer | ページ番号 |
| `notes[].quote` | string | 引用文 |
| `notes[].memo` | string / null | メモ |
| `notes[].created_at` | string | 作成日時 |
| `meta.total_count` | integer | 条件に一致した総件数 |
| `meta.page` | integer | 現在のページ番号 |
| `meta.limit` | integer | 1ページあたりの件数 |
| `meta.total_pages` | integer | 総ページ数 |
---
## 8. Empty Result
検索条件に一致するNoteが存在しない場合も、`200 OK` を返す。
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
## 9. Error Responses
### 400 Bad Request
クエリパラメータが不正な場合。
例：
- `page` が数値として扱えない
- `limit` が数値として扱えない
- `page_from` / `page_to` が数値として扱えない
- `page_from > page_to`
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
## 10. 本番確認済み挙動
本番環境で以下を確認済み。
- キーワード検索
  - `GET /api/books/:book_id/notes_search?q=Rails&page=1&limit=10`
  - `200 OK`
  - キーワードに一致するNoteのみ返却
- ページ範囲検索
  - `GET /api/books/:book_id/notes_search?page_from=10&page_to=20&page=1&limit=10`
  - `200 OK`
  - 指定したページ範囲に一致するNoteのみ返却
- 該当なし検索
  - `GET /api/books/:book_id/notes_search?q=nonexistentkeyword&page=1&limit=10`
  - `200 OK`
  - `notes: []`
- 不正なクエリパラメータ
  - `GET /api/books/:book_id/notes_search?page=abc&limit=10`
  - `400 Bad Request`
- 他ユーザーBookへのSearch
  - `404 Not Found`
  - 所有権情報を露出しない
---