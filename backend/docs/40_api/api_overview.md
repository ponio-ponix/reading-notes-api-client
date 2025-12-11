
# 読書引用インボックス API 仕様

## 0. 設計の目的（スタックフレームのアウトプット）

- 1リクエスト = 1スタックフレーム という前提で設計している。
  - コントローラの役割は「引数（パラメータ）を受け取り、Service を呼び、戻り値を JSON に変換する」だけ。
  - セッションに状態を隠さず、必要な状態はすべて DB とリクエストパラメータで表現する。
- 複雑な検索ロジック・ページネーションは `Notes::SearchNotes` Service に集約する。
  - Controller に `if params[:q] ...` や `where` の羅列を書かない。
- この API で示したいこと：
  - スタックフレームの概念を HTTP レイヤに落とし込んだ「関数っぽい」設計ができていること。
  - rails の「太ったコントローラ」パターンを避けて、Service レイヤで責務を分離できていること。


## 1. 共通仕様

- Base URL: `/api`
- Format: JSON
- Header:
  - `Content-Type: application/json`
- エラー時:
  - 共通フォーマットは `{ "errors": [ "message1", "message2", ... ] }`
  - ステータスコードで種類を区別（400 / 404 / 422 / 500）

---
### 1.1 共通レスポンス形式


```json
{
  "errors": [
    "error message 1",
    "error message 2"
  ]
}
```

### 1.2 API 共通エラー仕様

このドキュメントは、全 API エンドポイントが従うべき  
**エラーモデル・ステータスコードの使い分け・レスポンス形式** を定義する。

アプリ全体で統一したエラーハンドリングを行うことで、
実装・テスト・クライアントの利用体験を一貫させることを目的とする。

---

# 1.2.1 ステータスコードの基本方針

## 400 Bad Request  
**「リクエスト形式が壊れている or 必須構造を満たさない」**

例：
- 期待する JSON 構造でない
- 必須フィールドが欠落している（例：`notes` が存在しない）
- 配列が空である（`notes` が空）
- 上限件数など、リクエスト構造的な制約違反

---

## 404 Not Found  
**「対象リソースが存在しない」**

例：
- `book_id` に対応する Book が存在しない
- URL の ID に対応するリソースがない

---

## 422 Unprocessable Entity  
**「リクエスト形式は正しいが、モデルバリデーションに失敗」**

例：
- Note の `quote` が空
- `page` が 1 未満
- BulkCreate の中で `notes` の要素が部分的に invalid

---

## 500 Internal Server Error  
**「サーバ側の想定外のエラー」**

- 500 は予期しないエラー


---

# 1.2.2. 共通レスポンス形式

成功時：  
（各 API の設計に依存するため省略）

失敗時（全API共通）：

```json
{
  "errors": [
    "error message 1",
    "error message 2"
  ]
}

```

# 1.2.3. Bulk API 固有の 422 形式
BulkCreate のみ、
「どの要素が失敗したか」を示す専用形式を採用する。

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
- index は notes 内のインデックス番号
- messages は複数のバリデーションメッセージ配列
- API 全体の { "errors": [...] } ルート形式は維持する
