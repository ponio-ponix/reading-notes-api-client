# Bulk Create Notes API Contract

###　ノート一括作成（Bulk Create）

##　0. Purpose（この API の存在理由）

読書中の「連続メモ入力」を効率化するため、複数の Note を
1リクエストで原子的（atomic）に保存することを目的とする。

ユーザー体験（UX）上も、
一部だけ保存される中途半端な状態は許容できない。

---

## 1. Flow（連続メモ入力の流れ）

- ユーザーは「連続メモモード」を開く
- 縦に並んだ入力行（page / quote / memo）に次々入力していく
- 入力済みの行は一旦フロント側の下書きリストに保持される
- 最後に「◯件まとめて保存」ボタンを押す
- フロントは下書きリストを `notes` 配列として 1リクエストで送信する
- サーバ側では全件が valid のときだけ保存し、
  1件でも invalid な場合は全件ロールバックし、エラー情報を返す

---
## 2. Constraints（制約）

- 1リクエストあたりの `notes` の最大件数: 20件
- `notes` は必須の配列（空配列はエラー）


---

## 3. Validation Rules（入力のルール）

- `page`:
  - null 許容
  - null でない場合は 1 以上の整数
- `quote`:
  - 必須
  - 空文字・空白のみは NG
  - 最大 1000 文字
- `memo`:
  - 任意（null OK）
  - 最大 2000 文字
- `notes` 自体が配列でない or 空配列なら 400 Bad Request


---

## 4. Endpoint
**POST /api/books/:book_id/notes/bulk**

> **Transaction 観点メモ**
> - このエンドポイント単位で **1トランザクション** を張る  
> - 読み取り系（GET /notes など）とは違い、「書き込み系の境界」として扱う

---

## 5. Request / Response

## Request Body
```json
{
  "notes": [
    { "page": 12, "quote": "....", "memo": "..." },
    { "page": 13, "quote": "....", "memo": null }
  ]
}

```

## Success (201):

```json
{
  "notes": [
    { "id": 101, "page": 12, "quote": "...", "memo": "...", "created_at": "..." },
    { "id": 102, "page": 13, "quote": "...", "memo": null, "created_at": "..." }
  ],
  "meta": { "created_count": 2 }
}
```

#### エラー
- notes が空 / 配列でない … 400 Bad Request
  - 例: {"errors": ["notes must be a non-empty array"]}
- 要素数が上限を超える … 400 Bad Request
  - 例: {"errors": ["too many notes (max 20)"]}
- 要素の一部でバリデーションエラー … 422 Unprocessable Entity
  - 形式は共通仕様「1.1 Bulk API 固有のエラー形式」を参照
- 本が存在しない場合 … 404 Not Found

## Failure (422, 1件でも NG):

```json
{
  "errors": [
    { "index": 0, "messages": ["page must be greater than 0"] },
    { "index": 2, "messages": ["quote can't be blank"] }
  ]
}
```


## 6. エラー仕様

このセクションでは、Bulk Create API 固有のエラー仕様のみを定義する。  
共通エラー仕様（400 / 404 / 422 / 500 の一般的な意味・レスポンス形式）は  
**api_overview.md** を参照とし、本ファイルでは **差分のみ** を記述する。

---

## 6.1. Bulk Create のステータスコード運用

### 400 Bad Request（Bulk Create 固有ルール）

以下の Bulk Create 固有条件のとき 400 を返す：

- `notes` が **配列でない**
- `notes` が **空配列**
- `notes.size` が **上限（20件）を超える**

レスポンス例：

```json
{
  "errors": ["notes must be a non-empty array"]
}
```

### 404 Not Found（Bulk Create 固有ルール）
対象の Book が存在しない場合、404 を返す。

```json
{
  "errors": ["book not found"]
}
```

## 6.2. Bulk Create 固有の 422 エラー形式
Bulk Create では、どの入力行が invalid だったかを返す必要があるため
共通レスポンス { "errors": [...] } を拡張した専用形式を使用する。

```json
{
  "errors": [
    {
      "index": 0,
      "messages": ["page must be greater than 0"]
    },
    {
      "index": 2,
      "messages": ["quote can't be blank"]
    }
  ]
}

```
- index: notes 配列内の番号
- messages: その Note に対する複数のバリデーションエラー

この 422 が返るとき、
トランザクションは 1 件も保存せず全ロールバックされる。

## 6.3. トランザクション境界とエラーの関係（Bulk 固有）
-	1件でも invalid → 全件ロールバック
-	成功時は 201（Created）
-	部分成功は仕様上禁止（atomicity）



## 7. DB 制約（この API が前提とするもの）

- `notes.book_id` は `books.id` への外部キーとする
  - 誤削除を避けるため、`ON DELETE RESTRICT` を採用
- `quote` / `memo` の長さ制約は DB 側カラム定義と揃える
  - `quote`：最大 1000 文字
  - `memo`：最大 2000 文字

※ `(book_id, page, quote)` に対するユニーク制約は **MVP では貼らない**
  - 同じページ・同じ引用を重複して残したいケースも考えられるため
  - 重複禁止の要件が出た場合に、(book_id, page, quote) に unique index を追加する


## 8. 同時実行時のふるまい（簡易メモ）

- 同一 book に対する同時 Bulk Create は、DB ロックにより順序実行される
- Book 削除と Bulk Create が競合した場合、FK により Bulk が失敗する

詳細は transaction_policy.md を参照。


## 9. Transaction Boundary（この API が守る境界）

- 本エンドポイントは 1 HTTP Request を
  1つの論理的な書き込み単位（atomic operation） として扱う。

不変条件（Invariant）：：

- notes は「全部成功」または「全部失敗」のどちらか
- 部分的に保存される状態は発生しない

詳細なトランザクション方針（例：失敗時の扱い・整合性維持の仕組み）は
transaction_policy.md を参照。
