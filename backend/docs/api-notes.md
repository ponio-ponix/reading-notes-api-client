

# Notes API Specification

## 1. 共通

- Base URL: `http://localhost:3000`
- Resource: Book に紐づく Note
- 認証: なし（ローカル開発用）

---

## 2. List Notes

### Endpoint

`GET /api/books/:book_id/notes`

### 説明

- 指定した Book に紐づくノート一覧を返す
- キーワード検索 / ページ範囲指定 / ページネーション対応

### クエリパラメータ

| name        | type   | 必須 | 説明                                                     |
|-------------|--------|------|----------------------------------------------------------|
| `q`         | string | 任意 | `quote` / `memo` の部分一致キーワード                   |
| `page_from` | int    | 任意 | ページ下限（例: `10` → `page >= 10`）                   |
| `page_to`   | int    | 任意 | ページ上限（例: `20` → `page <= 20`）                   |
| `page`      | int    | 任意 | 何ページ目か（デフォルト `1`）                          |
| `limit`     | int    | 任意 | 1ページあたり件数（`1〜200`、デフォルト `50`）         |

### レスポンス 200

```json
{
  "notes": [
    {
      "id": 5,
      "book_id": 1,
      "page": 10,
      "quote": "人間は耐えることができるのだ。",
      "memo": "テスト用",
      "created_at": "2025-12-05T02:52:03.377Z"
    }
  ],
  "meta": {
    "total_count": 5,
    "page": 1,
    "limit": 50,
    "total_pages": 1
  }
}
```


⸻

## 3. Create Note

### Endpoint

`POST /api/books/:book_id/notes`

Request Body (JSON)

```json
{
  "note": {
    "page": 10,
    "quote": "人間は耐えることができるのだ。",
    "memo": "テスト用メモ"
  }
}
```

レスポンス 201（成功）


```json
{
  "id": 6,
  "book_id": 1,
  "page": 10,
  "quote": "人間は耐えることができるのだ。",
  "memo": "テスト用メモ",
  "created_at": "2025-12-05T03:00:00.000Z"
}
```

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


⸻

## 4. Delete Note

### Endpoint

`DELETE /api/books/:book_id/notes/:id`

### レスポンス 204（成功）

- Body なし

### レスポンス 404（Note が存在しない場合）

```json
{
  "error": "Not found"
}
```

---

