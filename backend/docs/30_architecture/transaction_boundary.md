# Transaction Boundary

## 現在の実装で保証していること（As-Is / Implemented）

### Bulk Create のトランザクション境界

**実装箇所**: `app/services/notes/bulk_create.rb` (L42-44)

```ruby
ActiveRecord::Base.transaction do
  notes.each(&:save!)
end
```

- 1 HTTP リクエスト（Bulk Create）= 1 DB トランザクション
- 全件成功 または 全件失敗（atomicity / 原子性）を保証
- 1件でも invalid な要素があれば `BulkInvalid` 例外を投げ、トランザクション全体をロールバック

### バリデーションとロールバックの実装

- 各 Note は ActiveRecord のモデルバリデーションで検証される（L33: `note.valid?`）
- バリデーションエラーがあれば保存前に例外を投げる（L40）
- トランザクションブロックに入る前に全件検証済みのため、save! の失敗はモデル制約違反時のみ

### 件数制限

- 1リクエストあたり最大 20 件（`MAX_NOTES_PER_REQUEST = 20`）
- 空配列は 400 Bad Request（L16-18）
- 上限超過時も 400 Bad Request（L19-21）

### HTTP ステータスとトランザクション結果の対応

| ステータス | トランザクション結果 | DB 状態 |
|------------|----------------------|---------|
| 201 Created | commit 成功 | 全件保存済み |
| 422 Unprocessable Entity | rollback 実行 | 0件保存 |
| 400 Bad Request | トランザクション未開始 | 0件保存 |

### FK制約による参照整合性

**実装箇所**: `db/schema.rb` (L36)

```ruby
add_foreign_key "notes", "books", on_delete: :restrict
```

- Book が削除されている場合、Bulk Create は FK 制約違反で失敗する
- 「削除済み Book に Note だけ残る」状態は DB レベルで防止されている

### Error Handling & Logging Policy（トランザクションと例外処理）

#### なぜトランザクション設計でエラーハンドリングを定義するのか

トランザクションの commit / rollback は例外の発生・伝播と不可分である。
「どの例外が発生したら rollback するか」「HTTP ステータスと DB 状態の対応」を明文化することで、
API 仕様とトランザクション境界の整合性を保証する。

#### 例外の分類と HTTP ステータスへのマッピング

**実装箇所**: `app/controllers/application_controller.rb` (L2-19)

| 例外クラス | HTTP Status | 分類 | 実装確認 |
|-----------|-------------|------|----------|
| `ApplicationErrors::BadRequest` | 400 Bad Request | 想定内 | ✓ |
| `ActionController::ParameterMissing` | 400 Bad Request | 想定内 | ✓ |
| `ActiveRecord::RecordNotFound` | 404 Not Found | 想定内 | ✓ |
| `ActiveRecord::RecordInvalid` | 422 Unprocessable Entity | 想定内 | ✓ |
| `ActiveRecord::RecordNotDestroyed` | 422 Unprocessable Entity | 想定内 | ✓ |
| `Notes::BulkCreate::BulkInvalid` | 422 Unprocessable Entity | 想定内 | ✓ |
| `ActiveRecord::NotNullViolation` | 422 Unprocessable Entity | DB制約違反 | ✓ |
| `ActiveRecord::InvalidForeignKey` | 422 Unprocessable Entity | DB制約違反 | ✓ |
| `ActiveRecord::RecordNotUnique` | 422 Unprocessable Entity | DB制約違反 | ✓ |
| `ActiveRecord::CheckViolation` | 422 Unprocessable Entity | DB制約違反 | ✓ (`defined?` ガード付き) |
| `StandardError` (その他) | 500 Internal Server Error | 想定外 | ✓ (本番のみ) |

**想定内エラー（400 / 422 系）:**
- アプリケーションが予期している失敗パターン
- クライアント側で修正可能なエラー
- エラー詳細をレスポンスに含める

**想定外エラー（500 系）:**
- アプリケーションが予期していない異常
- サーバ内部の問題
- エラー詳細はクライアントに返さず、ログに記録

#### HTTP ステータスとトランザクション状態の保証

| HTTP Status | トランザクション状態 | DB への副作用 |
|-------------|---------------------|---------------|
| 201 Created | commit 成功 | あり（意図通り） |
| 400 Bad Request | トランザクション未開始 | なし |
| 404 Not Found | トランザクション未開始 | なし |
| 422 Unprocessable Entity | rollback 実行済み | なし |
| 500 Internal Server Error | rollback 実行済み（transaction内の場合） | なし |

**設計原則:**
- 400 / 422 のエラーが返った場合、DB に副作用は一切残らない
- トランザクション内で例外が発生した場合、Rails が自動で rollback を実行する
- クライアントは「エラーレスポンスが返ったら、処理は失敗している」と判断できる

#### ログ出力ポリシー

**実装箇所**: `app/controllers/application_controller.rb` (L26-66)

全ハンドラでログ出力を行う。ログレベルはステータスに応じて使い分ける。

**ログ出力の方針:**

| エラー分類 | ログレベル | 出力例 | 理由 |
|-----------|-----------|--------|------|
| 400 (BadRequest / ParameterMissing) | `warn` | `[400] ApplicationErrors::BadRequest: ...` | 不正リクエストの傾向把握 |
| 404 | `info` | `[404] ActiveRecord::RecordNotFound: ...` | 想定内、頻度監視用 |
| 422 (RecordInvalid / BulkInvalid) | `info` | `[422] ActiveRecord::RecordInvalid: ...` | 想定内、頻度監視用 |
| 422 (DB制約違反) | `warn` | `[422][DB] ActiveRecord::NotNullViolation: ...` | モデルバリデーションをすり抜けた異常 |
| 500 | `error` | `Internal Server Error: ...` + スタックトレース | 想定外エラー、原因調査が必要 |

**本番環境のみの制約:**
- `rescue_from StandardError` は本番環境でのみ有効（`if Rails.env.production?`）
- 開発環境では詳細なエラー画面を表示し、デバッグを容易にする

#### 責務の分離（Service vs Controller）

**Service Layer の責務:**
- ドメイン上の失敗を例外として表現する
- 例：ApplicationErrors::BadRequest（入力不正）、BulkInvalid（バリデーション失敗）
- **ログ出力は行わない**（Controller に委ねる）

**Controller Layer の責務:**
- `rescue_from` により例外を HTTP レスポンスに変換する
- 全ハンドラでログ出力を行う（レベルは warn / info / error で使い分け）
- トランザクションの成否を HTTP ステータスで表現する

**この分離の意図:**
- Service は HTTP プロトコルに依存しない
- Service は再利用可能（CLI / バッチ処理でも使える）
- ログは「HTTP リクエストの失敗」として Controller で一元管理（全ステータスでログ出力）

#### スコープと制限事項

本エラーハンドリング設計は以下を前提とする：

- **低トラフィック環境**（個人開発・ポートフォリオ用途）
- **障害監視基盤は未導入**（Sentry / Datadog 等の外部サービスなし）
- **構造化ログは未実装**（JSON 形式・リクエストID 付与等なし）

将来的にトラフィック増加・運用高度化する場合は、以下を検討する：
- エラー率の監視・アラート
- リクエストトレーシング（correlation ID）
- 構造化ログ（ログ解析ツール対応）

**現時点では「一貫したエラーハンドリングルール」を示すことを目的とする。**

---

## テスト仕様による保証（Test Coverage）

本セクションでは、RSpec により**実際に検証されている保証**を明記する。
実装だけでなく、テストによって「壊れたら検知できること」を文書化する。

### Request Spec による保証

**検証ファイル**: `spec/requests/api/notes_bulk_spec.rb`

#### BulkInvalid → 422 のエンドツーエンド保証

**検証箇所**: L6-35

検証している事項：
1. HTTP ステータスが `422 Unprocessable Entity` であること（L22）
2. レスポンス body がBulkCreate 固有の 422 エラー形式であること  （詳細は docs/40_api/api_overview.md を参照）
3. DB に Note が 1件も作成されていないこと（L18-20: `.not_to change { Note.count }`）

**このテストが検知できる破壊的変更:**
- `rescue_from Notes::BulkCreate::BulkInvalid` が削除された
- HTTP ステータスが 422 以外に変わった
- レスポンス形式が変更された
- `ActiveRecord::Base.transaction` が削除され、一部の Note だけ保存されるようになった
- Controller が Service を呼ばなくなった

#### ApplicationErrors::BadRequest → 400 のエンドツーエンド保証

**検証箇所**: L37-55

検証している事項：
1. HTTP ステータスが `400 Bad Request` であること（L46）
2. レスポンス body が `{ errors: [String] }` 形式であること（L48-52）
3. DB に Note が 1件も作成されていないこと（L42-44: `.not_to change { Note.count }`）

**このテストが検知できる破壊的変更:**
- `rescue_from ApplicationErrors::BadRequest` が削除された
- ApplicationErrors::BadRequest が 422 / 500 に化けた
- transaction 外で副作用が発生するようになった

### Service Spec による保証

**検証ファイル**: `spec/services/notes/bulk_create_spec.rb`

#### Transaction による rollback の保証

**検証箇所**: L126-162

検証している事項：
- `save!` が transaction 内で途中失敗した場合でも、DB に Note が 1件も作成されないこと（L154-160: `.not_to change { Note.count }`）
- テスト内で `before_save` callback により意図的に save! を失敗させ、rollback を検証している

**検証方法:**
- transaction の存在を直接テストしていない
- 結果として「DB に副作用が残らない」ことを検証している
- save! が 2件目で失敗しても、1件目が残らないことで rollback を検知

**このテストが検知できる破壊的変更:**
- `ActiveRecord::Base.transaction` が削除された
- transaction のスコープが不適切になった
- 一部の Note だけ保存される実装に変わった

### HTTP ステータスとトランザクション結果の対応（更新版）

以下の表は**実装と Request Spec の両方で保証されている**：

| ステータス | トランザクション結果 | DB 状態 | 検証方法 |
|------------|----------------------|---------|---------|
| 201 Created | commit 成功 | 全件保存済み | 実装のみ（Request Spec 未実装） |
| 422 Unprocessable Entity | rollback 実行 | 0件保存 | **Request Spec で検証済み** (notes_bulk_spec.rb L18-20) |
| 400 Bad Request | トランザクション未開始 | 0件保存 | **Request Spec で検証済み** (notes_bulk_spec.rb L42-44) |

**注記:**
- 201 成功ケースは Request Spec で未検証（意図的に除外）
- 422 / 400 のエラーケースは Request Spec により「壊れたら検知できる」ことが保証されている

---

## 同時実行時の挙動（Concurrency）

### 現状の方針

- **現時点では明示的な並行制御を実装していない**
- PostgreSQL のデフォルト分離レベル（READ COMMITTED）と Rails の挙動に委ねている
- 個人開発・低トラフィック前提のため、複雑なロック制御は導入していない

### 想定される挙動（PostgreSQL デフォルト）

1. **同一 Book への同時 Bulk Create**
   - PostgreSQL の MVCC により、互いに干渉せず並行実行される
   - 書き込みロックは各 Note 行単位で取得される
   - デッドロックは発生しにくいが、可能性はゼロではない

2. **Book 削除と Bulk Create の競合**
   - FK 制約（ON DELETE RESTRICT）により、Notes が存在する Book は削除不可
   - 削除が先に成功した場合、Bulk Create は FK 違反で失敗する

---

## 将来的に検討している設計方針（To-Be / Future Consideration）

以下は現時点で実装されていないが、トラフィック増加時に検討する方針。

### 明示的ロック制御

- Book 単位での排他ロック（`SELECT ... FOR UPDATE`）の導入
- 同一 Book への同時書き込みを完全に直列化する場合に検討

### 再実行ポリシー

- デッドロック発生時の自動リトライ
- Sidekiq 等のジョブキュー導入時に検討

### トランザクション設計の一般原則

- 1 HTTP Request = 1 トランザクション の原則を維持
- 読み取り専用クエリはトランザクション外で実行
- トランザクションスコープは最小限（ロック時間を短く保つ）

---

## まとめ

**現在の実装は以下を保証する:**

- Bulk Create の全件成功 or 全件失敗（atomicity）
- FK 制約による参照整合性
- 件数制限によるトランザクション重量制御

**現在は保証していないが、将来検討する要素:**

- 明示的な並行制御（行ロック・楽観ロック等）
- デッドロック時のリトライ
- 高トラフィック時のスケール戦略
