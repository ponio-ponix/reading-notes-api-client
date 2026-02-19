# Error Handling（例外設計・境界）

> Docs Scope（役割）
> 本ドキュメントは例外設計方針（4xx/5xx 境界・rescue_from 方針）を定義する。
> API レスポンス形式（errors の型など）の最終定義（SSOT）は `docs/40_api/api_overview.md` とする。
> 本ドキュメントを含む他の設計文書は、当該仕様を上書きしてはならない。


## 目的
- API のエラーを **「ユーザー入力ミス（4xx）」** と **「サーバ側バグ（5xx）」** に分離し、運用とデバッグの精度を上げる。
- 特に、Ruby/Rails/gem が投げる `ArgumentError` 等を **誤って 400 に変換してバグを隠す事故**を防ぐ。

---

## Context（Why this rule exists）

- Notes Bulk / Search の request spec 作成中、**4xx（入力エラー）と 5xx（バグ）の境界が曖昧になり設計が破綻**
- `ArgumentError` を 400 に変換すると、**本来 500 として検知すべきバグまで 4xx に埋もれる**と判明
- 以後、**「意図して投げた例外のみを 4xx、その他は 5xx」**に固定

---

## 基本方針（結論）

### 1) 400 は「アプリが意図して投げた例外」だけにする
- 400 を返すのは **アプリ固有の例外クラス**に限定する。
- Ruby/Rails/gem の例外を広く rescue して 400 に落とさない。

### 2) 500 は「想定外の例外（= バグ）」として扱う
- 想定外例外は 500 を返し、ログ・監視で検知できる状態にする。
- 本番では `StandardError` を 500 に変換し、スタックトレースをログに残す。

---

## なぜ `rescue_from ArgumentError` がダメか
`ArgumentError` は Ruby 標準の一般例外で、次のような「入力ミス」と「バグ」の両方で発生しうる：

- Ruby 標準ライブラリ（`Integer()`, `Date.parse`, `URI.parse`, `Regexp.new` など）
- Rails 内部（`permit` の誤用、クエリ組み立ての誤用など）
- 外部 gem（バージョン差で例外クラスが変わることもある）

そのため `rescue_from ArgumentError -> 400` を置くと、
**本来は 500 で検知すべきバグが 400 になって静かに埋もれる**。

---

## 例外クラス設計（最小）

### アプリ固有の 400 系例外
- `ApplicationErrors::BadRequest < StandardError`

必要になったらサブクラスを増やす（例：`InvalidParameter`, `InvalidNotesPayload` など）。
ただし最初は増やさず、まず「境界を切る」ことを優先する。

---

## rescue_from の探索順と「宣言順ルール」

Rails の `rescue_from` は **ハンドラが継承され**、例外発生時に次の順で探索される：

- **右 → 左**
- **下 → 上**
- **親クラス方向へ（hierarchy を遡る）**

つまり、**最後に登録された handler が優先されやすい（後勝ち）**。

そのため本プロジェクトでは、意図しない例外の握りつぶしを避けるために  
**「より具体的な例外を後に書く」**ことをルールとする。

例：`StandardError` は production の **最終受け皿**として使うため、  
4xx/422 の例外より **先に宣言しない**（食われる事故防止）。

参考（公式）：
- ActionController::Rescue `rescue_from` API  
  https://api.rubyonrails.org/v7.0.7/classes/ActiveSupport/Rescuable/ClassMethods.html

---

## Controller / Service の責務：Book存在確認（alive）の置き場所

> **Note**: 本セクションは [soft_delete_policy.md](../20_design/soft_delete_policy.md#alive-チェックの責務原則) の例外規定を詳述したものです。

### 結論
- `Notes::BulkCreate` のように **Service が `Book.alive.find(book_id)` を行う場合**、  
  Controller 側で同じ存在確認（`before_action :set_book`）を **重ねない**。
- 同一リクエストで **同じBook取得が2回走る（二重クエリ）**のを防ぐため。

### ルール
- Controller が `@book` を使うなら `set_book` は置いてよい（例：createで `@book.notes.create!` を呼ぶ場合）
- Controller が `@book` を使わないなら `set_book` は置かない（存在確認は Service に寄せる）

### 実例
- ✅ OK: `Api::NotesController#create`
  - Controller が `@book.notes.create!` を実行するので `set_book` が必要
- ✅ OK: `Api::NotesBulkController#create`
  - Book存在確認は `Notes::BulkCreate` 側で実施するため `set_book` は不要（削除済み）

## rescue_from ルール（ApplicationController）

### 4xx（意図した失敗）
- `ApplicationErrors::BadRequest` -> 400
- `ActionController::ParameterMissing` -> 400
- `ActiveRecord::RecordNotFound` -> 404
- `ActiveRecord::RecordInvalid` / `RecordNotDestroyed` -> 422
- `Notes::BulkCreate::BulkInvalid` -> 422（Bulk専用）

### 422（DB制約違反）
- `ActiveRecord::NotNullViolation` -> 422
- `ActiveRecord::InvalidForeignKey` -> 422
- `ActiveRecord::RecordNotUnique` -> 422
- `ActiveRecord::CheckViolation` -> 422（`defined?` ガード付き）

レスポンス: `{ "errors": ["DB constraint violated"] }`（固定メッセージ）

### 5xx（想定外 = バグ）
- `StandardError` -> 500（production のみ）

### 禁止
- `ArgumentError` を rescue_from して 400 に落とすことは禁止
  （理由：バグまで 400 に変換して検知不能になる）

---

## Service / Controller から例外を投げる時のルール

### 400 にしたい時
- `raise ApplicationErrors::BadRequest, "..."` を使う  
  もしくは将来の拡張で `InvalidParameter` 等のサブクラスを使う。

### バグの可能性がある時
- Ruby/Rails/gem の例外を握りつぶして 400 にしない。
- 例外をそのまま上げて 500 にして、ログで検知できる状態にする。

---

## エラーレスポンス形式（API 共通）
- 共通: すべてのエラーレスポンスは `{ errors: ... }` 形式を持つ。
- デフォルト型: `errors: string[]`
- 例外: BulkCreate の 422 のみ
  `errors: Array<{ index: number, messages: string[] }>`
- errors 形式の最終決定権（SSOT）は`docs/40_api/api_overview.md` とする。本ドキュメントを含む他の設計文書は、当該仕様を上書きしてはならない。

例：
```json
{ "errors": ["page must be an integer"] }