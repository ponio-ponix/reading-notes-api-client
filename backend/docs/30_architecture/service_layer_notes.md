# Service Layer Design（Notes / Books）

サービス層（UseCase）の責務分離

本ドキュメントでは、**Controller / Service / Model** の責務分担を明文化する。

対象：
- Books API（一覧取得のみ）
- Notes API（作成・削除）
- Notes 検索 API（構造化引用検索）
- Bulk Create Notes API

---

## 1. レイヤーの基本方針

### 1.1 Controller の責務

- HTTP リクエスト／レスポンスの変換に限定する
  - params を適切な型・名前に変換して Service に渡す
  - Service の戻り値を JSON に整形して返す
- エラーハンドリングの入り口
  - `rescue_from` で Domain / Application 例外を HTTP ステータスにマッピング
- ビジネスロジックは書かない
  - `where` 連発、条件分岐だらけの if / else は Controller では禁止

### 1.2 Service（Application 層）の責務

- 「1ユースケース = 1メソッド（or 1クラス）」で表現する
  - 例：
    - `Notes::SearchNotes.call(...)`
    - `Notes::BulkCreate.call(...)`
- トランザクション境界を張る層
  - 書き込み系（BulkCreate など）は Service 層で `transaction` を開始する
- Domain ルールの入口
  - 「今回のリクエストで何がしたいか」を言語化したレベルのロジックを書く
  - Model に閉じ込めない

### 1.3 Model（ActiveRecord）の責務

- 永続化／バリデーション／関連の定義
- 単純なスコープ
  - 例：`scope :recent, -> { order(created_at: :desc) }`
- 複雑な検索・ユースケースは書かない
  - where が5行以上になるような検索条件は、`Notes::SearchNotes` など Service / QueryObject 側で扱う

---

## 2. ユースケース別の役割分担

### 2.1 Books 一覧取得（GET /api/books）

- Controller
  - `Book.all.order(:id)` を呼び出し、JSON に整形
  - 複雑な条件はないので Service は **作らない**
- Model
  - `Book` モデルにバリデーション・関連のみ定義

→ ここは「シンプル CRUD」として Controller + Model のみ。

---

### 2.2 Notes 検索（GET /api/books/:book_id/notes）

- Controller（`Api::NotesSearchController#index`）
  - params を受け取り、`Notes::SearchNotes.call(...)` に渡す
  - 戻り値の `notes, meta` を JSON に変換
- Service（`Notes::SearchNotes`）
  - 検索条件（`q`, `page_from`, `page_to`）の適用
  - ページング処理（`page`, `limit`, `offset` 計算）
  - `total_count` の計算
  - ソート条件の適用（`created_at DESC`）
  - 必要であれば QueryObject に委譲してもよい（後述）
- Model（`Note`）
  - スキーマ定義・バリデーションのみ
  - 検索条件の組み合わせロジックは書かない

---

### 2.3 Note 単一作成（POST /api/books/:book_id/notes）

- Controller
  - `@book = Book.alive.find(params[:book_id])`
  - `@book.notes.new(note_params)` でインスタンス生成
  - `save` 結果に応じて 201 / 422 を返す
- Service
  - MVP では **専用の Service は作らない**（複雑化してから検討）
- Model
  - バリデーションを厳密に定義（page / quote / memo の制約）
  - エラーメッセージは API 仕様と整合を取る

---

### 2.4 Note 削除（DELETE /api/notes/:id）

- Controller
  - `Note.find_by(id: params[:id])` で取得
  - 見つからなければ 404
  - 見つかれば `destroy` して 204 を返す
- Service
  - 現時点では **不要**
  - 将来的に「権限チェック」「論理削除」「履歴保存」などが乗ったら Service 化

---

### 2.5 Notes 一括作成（POST /api/books/:book_id/notes/bulk）

- Controller（`Api::NotesBulkController#create`）
  - `book_id` と `notes_params` を Service に丸投げ
  - 成功時 201 / 失敗時 422 or 400 の JSON を返す
  - `rescue_from` で `BulkInvalid` / `ArgumentError` を HTTP ステータスにマッピング
- Service（`Notes::BulkCreate`）
  - `notes` 配列の前提チェック（空配列 / 上限件数）
  - 1件ずつ `Note` を build & validate
  - 1件でも invalid なら `BulkInvalid` を投げる
  - `transaction` ブロックで全件保存 or 全ロールバック
  - 成功時は作成した Note の配列を返す
- Model
  - 単一 Note のバリデーションのみを担当
  - Bulk 特有のロジックは Model には書かない

---

## 3. QueryObject の役割（必要になったら切り出す）

`Notes::SearchNotes` が肥大化してきたら、以下のような QueryObject を導入する。

- `Notes::NoteQuery`
  - `initialize(relation = Note.all)` で base scope を受け取る
  - `by_book(book_id)` / `keyword(q)` / `page_range(from:, to:)` などのメソッドをチェーン可能にする
  - 例：
    - `Notes::NoteQuery.new(Note.all).by_book(book_id).keyword(q).page_range(from:, to:).relation`

MVP の段階では無理に導入しない。
`SearchNotes` が 150〜200行に近づいてきたら検討する。

---

## 4. TODO: フロントエンド下書き（Draft）UI の将来構想

### 動機

- 読書中の高速連続入力を実現したい
- 複数ノートを一括保存し、行単位でエラー表示したい
- Bulk Create API（`POST /notes/bulk`）のフロント統合が必要

### 将来案

- **A) クライアントローカル下書き**
  - localStorage / state で下書きを保持
  - 「まとめて保存」ボタンで `/notes/bulk` に POST
  - 422 時は `errors[].index` を下書き行にマッピング

- **B) サーバ側 Draft エンドポイント**
  - `/draft_notes` を別途設計し、下書き状態を DB 管理
  - 確定時に `/notes/bulk` へ変換

### 現時点の判断

API 契約・UI 仕様が固まっていないため、今回の PR（AND 検索）からは外した。
Bulk Create API のバックエンド実装は完了済み。フロント統合は別 PR で対応予定。