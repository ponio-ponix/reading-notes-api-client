# Test Strategy - Notes / Books API

本ドキュメントでは、Notes / Books API 周りのテスト方針（RSpec）をまとめる。

---

## 1. テストレイヤー構成

### 1.1 Request Spec（API レベル）

- 対象
  - `GET    /api/books`
  - `GET    /api/books/:book_id/notes`
  - `POST   /api/books/:book_id/notes`
  - `DELETE /api/notes/:id`
  - `POST   /api/books/:book_id/notes/bulk`
- 目的
  - API 仕様（ステータスコード・レスポンス JSON・エラー形式）がドキュメント通りか検証する
  - 「外から見える契約」が壊れていないかチェック

### 1.2 Service Spec

- 対象
  - `Notes::SearchNotes`
  - `Notes::BulkCreate`
- 目的
  - 検索条件の組み合わせ・トランザクション境界など、純粋なビジネスロジックを検証する
  - Controller に依存しない形でロジックをテスト可能にする

### 1.3 Model Spec（最低限）

- 対象
  - `Book`
  - `Note`
- 目的
  - バリデーション（必須／桁数）と関連（`has_many` / `belongs_to`）の正常系・異常系をざっと押さえる

---

## 2. Request Spec のイメージ

### 2.1 GET /api/books

- 正常系
  - 2冊以上の Book を作成しておき、一覧 JSON が id / title / author のみを返すこと
- 異常系
  - 特になし（MVPではシンプル）

---

### 2.2 GET /api/books/:book_id/notes

テスト観点：

1. `book_id` が存在する場合の基本動作
   - ノートが 3件あれば `notes.size == 3`
   - `meta.total_count` が正しい
2. `book_id` が存在しない場合
   - 404 が返る
3. `q` による検索
   - `quote` / `memo` のどちらかにキーワードが含まれるノートだけ返す
4. `page_from` / `page_to` のページ範囲
   - 10〜20 ページのノートだけ返ること
5. ページング
   - 例えば 30件作って `limit=10` のとき、
     - `page=1` → 先頭10件
     - `page=2` → 次の10件
     - `meta.total_pages == 3`
6. パラメータ異常
   - `page=-1` や `limit=0` のとき 400 が返ること（実装に合わせる）

---

### 2.3 POST /api/books/:book_id/notes

- 正常系
  - 正しい JSON を投げると 201 が返り、Note が1件増えている
- 異常系
  - `quote` が空 → 422 + `errors` にメッセージ
  - Book が存在しない → 404 + `{"error": "Book not found"}`

---

### 2.4 DELETE /api/notes/:id

- 正常系
  - 対象 Note が削除され、204 が返る
- 異常系
  - 存在しない id → 404 + `{"error": "Not found"}`

---

### 2.5 POST /api/books/:book_id/notes/bulk

- 正常系
  - `notes` を2件投げる → 201 + `meta.created_count == 2`
  - DB の Note が2件増えている
- 異常系（400）
  - `notes` が空配列 → 400 + エラーメッセージ
  - 上限 20件を超える → 400
- 異常系（422）
  - 3件中1件だけ `quote` が空 → 422
  - その場合 Note は1件も増えていない（全ロールバック）

---

## 3. Service Spec の観点

### 3.1 Notes::SearchNotes

テストしたいこと：

1. book_id でのスコープ
   - 他の Book の Note が混ざらない
2. キーワード検索
   - `quote` にだけマッチするケース
   - `memo` にだけマッチするケース
   - 大文字小文字を無視できているか（ILIKE 相当）
3. ページ範囲
   - from / to 片方だけ指定
   - 両方指定
4. ページング計算
   - `total_count` / `total_pages` の計算が正しいか
5. パラメータ異常
   - page < 1 / limit 範囲外で `ArgumentError` を投げる

---

### 3.2 Notes::BulkCreate

テストしたいこと：

1. 正常系
   - 2件の Note を渡して call → 2件とも保存される
2. トランザクションの原子性
   - 3件中2件目だけ invalid な入力を渡す
   - call が `BulkInvalid` を投げる
   - DB には1件も保存されていない（ロールバックされている）
3. 入力前提のチェック
   - `notes_params` が配列でない → `ArgumentError`
   - 空配列 → `ArgumentError`
   - 21件以上 → `ArgumentError`
4. エラーオブジェクトの中身
   - `BulkInvalid#index` と `messages` が期待通り

---

## 4. 優先度

MVP フェーズでは、テストを書く優先順位は以下とする：

1. `Notes::BulkCreate` の Service Spec（トランザクション保証が重要）
2. `Notes::SearchNotes` の Service Spec（検索の本質ロジック）
3. `GET /api/books/:book_id/notes` の Request Spec（契約テスト）
4. `POST /api/books/:book_id/notes/bulk` の Request Spec
5. 残りの CRUD（Books / Note 単一作成 / 削除）
