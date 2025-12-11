# ノート一覧取得（検索＋ページネーション対応）

本ドキュメントは、**構造化引用検索** の中核となるエンドポイント  
`GET /api/books/:book_id/notes` の仕様だけを切り出して定義する。

- Base URL（開発）: `http://localhost:3000`
- Resource: Book に紐づく Note
- 認証: なし（ローカル開発用）

---

## 1. Endpoint 概要

### 1.1 エンドポイント

**GET /api/books/:book_id/notes**

### 1.2 用途

- 指定した Book に紐づくノート一覧を返す
- 以下の条件で検索・絞り込み・ページングを行う
  - キーワード検索（`q`）
  - ページ範囲指定（`page_from` / `page_to`）
  - ページング（`page` / `limit`）

このエンドポイントが「構造化引用検索」機能の土台に

---

## 2. パラメータ仕様

### 2.1 パスパラメータ

| name      | type    | 必須 | 説明                    |
|-----------|---------|------|-------------------------|
| `book_id` | integer | YES  | 対象となる Book の ID   |

---

### 2.2 クエリパラメータ

| name        | type    | 必須 | デフォルト | 説明                                                                 |
|-------------|---------|------|------------|----------------------------------------------------------------------|
| `q`         | string  | 任意 | `nil`      | `quote` / `memo` に対する部分一致キーワード                         |
| `page_from` | integer | 任意 | `nil`      | ページ下限（例: `10` → `page >= 10`）                                |
| `page_to`   | integer | 任意 | `nil`      | ページ上限（例: `20` → `page <= 20`）                                |
| `page`      | integer | 任意 | `1`        | 何ページ目か（1 始まり、`page >= 1`）                                |
| `limit`     | integer | 任意 | `20`       | 1ページあたり件数（`1〜50` の範囲で指定。上限を超えたら 400）       |

---

## 3. パラメータのバリデーションルール

このエンドポイントでは、**入力がおかしい場合は 400 Bad Request を返す**。

### 3.1 `page`

- 未指定 or 空文字 → `1` とみなす
- 数値に変換できない → **400 Bad Request**
- `page < 1` → **400 Bad Request**

### 3.2 `limit`

- 未指定 or 空文字 → `20` とみなす
- 数値に変換できない → **400 Bad Request**
- `limit < 1` または `limit > 50` → **400 Bad Request**

### 3.3 `page_from` / `page_to`

- 未指定 → 無視
- いずれかが数値に変換できない → **400 Bad Request**
- 両方指定されていて `page_from > page_to` → **400 Bad Request**

> 400 のレスポンス形式は `api_overview.md` の共通エラー仕様に従う。

---

## 4. 検索条件の適用順序（Contract）

本エンドポイントにおける検索条件は、  
以下の順序で **AND 結合** により適用される。

### 4.1 必須条件

- `book_id = :book_id`

Rails 的には：

```rb
scope = Note.where(book_id: book.id)
```


## 4.2 キーワード検索（任意）

`q` が指定された場合、以下の OR 条件を部分一致で適用する。

- `quote ILIKE '%q%'`
- `memo  ILIKE '%q%'`

検索は PostgreSQL の `ILIKE` に相当する挙動を想定する（大文字・小文字を無視）。

---

## 4.3 ページ範囲フィルタ（任意）

ページ番号を用いた範囲指定。  
指定されている項目のみ適用する。

- `page_from` のみ指定 → `page >= page_from`
- `page_to` のみ指定 → `page <= page_to`
- `page_from` と `page_to` の両方指定 → `page BETWEEN page_from AND page_to`

※ `page_from` と `page_to` の両方が指定され、`page_from > page_to` の場合は  
**400 Bad Request** とする（パラメータエラー）。

---

## 4.4 ソート順序（Contract）

検索結果の順序は常に **`created_at DESC`（新しい順）** とする。

```rb
scope = scope.order(created_at: :desc)

```


---

## 4.5 ページング（page / limit）


ページング処理は以下の契約に従う。

page

- 未指定 → 1
- 数値でない → 400
- page < 1 → 400

limit

- 未指定 → 20
- 数値でない → 400
- page < 1 → 400

### 4.5.2 offset の計算式

```rb
offset = (page - 1) * limit
```

### 4.5.3 total_count の定義

total_count は「検索条件をすべて適用した後の総件数」。

```rb
book_id=1 のノート 200 件
キーワード q="愛" を適用 → 37 件
ページ範囲 page_from=10 を適用 → 12 件
limit=5 のとき
  total_count = 12
  total_pages = ceil(12 / 5) = 3

```

## 5. レスポンス仕様

---

## 5.1 成功時（200 OK）

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
    "limit": 20,
    "total_pages": 1
  }
}
```

### 5.1.1 `meta` オブジェクト仕様

検索結果に付随する `meta` の構造は以下のとおり。

| key          | 型  | 説明 |
|--------------|-----|------|
| `total_count` | int | 条件にマッチしたノートの総件数 |
| `page`        | int | 現在のページ番号 |
| `limit`       | int | 1ページあたりの最大件数 |
| `total_pages` | int | `ceil(total_count / limit)` の結果 |