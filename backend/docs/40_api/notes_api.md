

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

**パラメータ制約**：
- `quote`（必須、文字列）
  - 最大長: 1000文字
  - 空文字列不可
  - **注意**: 前後の空白は自動削除される（trim処理）。空白のみの文字列は削除後に空になるためバリデーションエラー
- `memo`（任意、文字列 or null）
  - 最大長: 2000文字
  - null 許可
  - 前後の空白は自動削除される
- `page`（任意、整数）
  - 最小値: 1以上
  - null 許可

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

#### エラーレスポンス

**404 Not Found（Book が存在しない場合）**
```json
{
  "errors": ["Couldn't find Book with 'id'=999999"]
}
```

**422 Unprocessable Entity（バリデーションエラー）**

以下の場合にバリデーションエラーが発生：
- quote が空文字列、または空白のみ（"   " → trim後に ""）
- quote が1000文字超
- memo が2000文字超
- page が1未満、または整数でない

レスポンス例：
```json
{
  "errors": [
    "Quote can't be blank",
    "Memo is too long (maximum is 2000 characters)"
  ]
}
```

**注意**: エラーメッセージは `errors` 配列で返却される（full_messages形式）




---

### 2.5 ノート削除

### Endpoint
**DELETE /api/notes/:id**

指定したノートを 1 件削除する。

#### Request
- パスパラメータ:
  - `id`: ノートID（整数）

#### Response 204 No Content
削除成功時は空のボディで 204 を返す。

#### エラーレスポンス

**404 Not Found（Note が存在しない場合）**
```json
{
  "errors": ["Couldn't find Note with 'id'=999999"]
}
```

指定された ID のノートが存在しない場合、404 エラーが返される。

---

## TODO: 将来の下書き（Draft）UI 構想

### 動機
- フロントで「下書き」を持つことで、高速入力・一括保存・行単位エラー表示を実現したい

### 候補案
- **A) クライアントローカル下書き**: localStorage 等で下書きを保持し、bulk save API で一括送信
- **B) サーバ側 Draft エンドポイント**: `/draft_notes` 等を別途設計し、下書き状態をサーバで管理

### 現状の判断
- API 契約が固まっていないため、今回の PR からは除外
- 将来的に実装する際は、上記候補を比較検討して決定する
