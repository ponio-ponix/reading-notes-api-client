# Bulk Create Notes API Contract

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


> **Transaction 観点メモ**
> - 「◯件まとめて保存」ボタン押下 = **1つの状態遷移ユニット**
> - ここで **1 HTTP リクエスト = 1 トランザクション** という設計前提が決まる

---
## 2. Constraints（制約）

- 1リクエストあたりの `notes` の最大件数: 20件
- `notes` は必須の配列（空配列はエラー）
- 単一ユーザー前提（同時更新は考えない／MVP）

> **Transaction 観点メモ**
> - 上限 20件は「1トランザクションの重さ」を制御するための制約  
>   → 1トランザクションに無制限件数を詰め込まない設計
> - 空配列をエラーにすることで、「意味のないトランザクション」を避ける

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


> **Transaction 観点メモ**
> - ここで定義したルールに違反した時点で、  
>   **トランザクションをロールバックさせるトリガー** になる
> - 実装では `note.valid?` / `note.save!` のどちらかで例外を投げ、  
>   トランザクションブロック全体を失敗させる

---

## 4. Endpoint

`POST /api/books/:book_id/notes/bulk_create`

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

> **Transaction 観点メモ**
> - 201 が返っている時点で、20件までの insert がすべてコミットされた状態 を意味する
> - created_count は「コミットされたレコード数」をフロントに伝える役割  



## Failure (422, 1件でも NG):
```json
{
  "errors": [
    { "index": 0, "messages": ["page must be greater than 0"] },
    { "index": 2, "messages": ["quote can't be blank"] }
  ]
}
```
> **Transaction 観点メモ**
> - 422 が返るときは、DB には1件も書き込まれていない（全ロールバック済み）ことが前提  
> - index は「どの入力行が原因でトランザクションが失敗したか」を示す


## Transaction Boundary（この API が守る境界）
### 1 HTTP Request  
    = 1 Service 呼び出し  
        = 1 DB Transaction
    •	すべての Note を 1つのトランザクション で保存する
	•	1件でも invalid → 全件ロールバック
	•	部分成功は明示的に禁止する（atomicity）

Invariant（不変条件）
	•	「bulk_create は “中途半端な状態” を絶対に作らない」
	•	“notes テーブルの整合性” は常に保たれる


## 不変条件：
- 1リクエスト内の notes は「全部成功 or 全部失敗」
- 途中1件でも invalid ならトランザクション全体ロールバック