

# Notes API Specification

## 1. 共通

- Base URL: `http://localhost:3000`
- Resource: Book に紐づく Note
- 認証: なし（ローカル開発用）

---

## 2. List Notes






### 2.3 ノート単一作成

### Endpoint
**POST /api/books/:book_id/notes**

指定した本に対して、引用ノートを 1 件作成する。

#### Request Body

```json
{
  "note": {
    "page": 10,
    "quote": "人間は耐えることができるのだ。",
    "memo": "テスト用メモ"
  }
}
```

- page  : ページ番号（整数, 任意）
- quote : 引用本文（必須, 文字列）
- memo  : 自分のメモ（任意, 文字列 or null）

#### Response 201 Created
```json
{
  "id": 15,
  "book_id": 1,
  "page": 123,
  "quote": "人間は状況に対して態度を選択する自由がある。",
  "memo": "フランクルの中心命題っぽい",
  "created_at": "2025-12-01T10:21:11Z"
}
```

#### エラー
- 本が存在しない場合 … 404 Not Found
- バリデーションエラー … 422 Unprocessable Entity
- memo  : 自分のメモ（任意, 文字列 or null）


### レスポンス 422（バリデーションエラー例）

```json
{
  "errors": {
    "page": ["must be greater than 0"],
    "quote": ["can't be blank"]
  }
}
```

### レスポンス 404（Book が存在しない場合）

```json
{
  "error": "Book not found"
}
```




---

### 2.5 ノート削除

### Endpoint
**DELETE /api/notes/:id**

指定したノートを 1 件削除する。

- Request
  - パスパラメータ:
    - id : ノートID

  - Response 204 No Content
  - ボディなし

#### エラー
  - ノートが存在しない … 404 Not Found
    - 例: {"error": "Not found"}

---

