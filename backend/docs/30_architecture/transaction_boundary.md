#　あとまわし

# Transaction Boundary

このアプリケーションでは、以下の原則でトランザクション境界を定義する。

- 1 HTTP Request = 1 Domain Operation = 1 DB Transaction
- 書き込み系は必ずトランザクションで保護する
- 部分成功は明示的に禁止し、atomicity（原子性）を保証する
- 読み取り系は基本的にトランザクション不要（Rails のデフォルト READ COMMITTED を採用）

### Bulk Create の件数制限

- 1リクエストあたり最大 20 件までに制限する
  - 理由：1トランザクションの重さを制御し、ロック時間と失敗時の巻き戻しコストを抑える
- 空配列は 400 Bad Request とする
  - 理由：意味のないトランザクション（BEGIN→COMMITだけ）を発行しない

### バリデーションとロールバックの関係（Bulk Create）

- Bulk Create では、各要素を `Note` モデルのバリデーションで検証する
- 1件でも invalid な要素があれば、例外（Notes::BulkCreate::BulkInvalid）を投げる
- その例外は transaction ブロックの外まで伝播し、DBトランザクション全体がロールバックされる
- API レベルでは常に「全部成功（201）」か「全部失敗（422）」のどちらかになる

### HTTP ステータスとトランザクション結果の対応

- Bulk Create の場合
  - 201 Created:
    - DB トランザクションが正常にコミットされ、全てのノートが保存された状態
  - 422 Unprocessable Entity:
    - バリデーションエラーによりトランザクションがロールバックされ、1件も保存されていない状態
- `meta.created_count` は、コミットされたレコード数を明示的に返すためのフィールド

## 同時実行時のふるまい（Concurrency Policy）

本アプリでは高い同時実行を想定しないが、以下の最低限の整合性を保証する。

1. 同じ Book に対して Bulk Create が同時に来た場合
   - DB の行ロックにより順番に実行される
   - ノートが消える、部分破壊されるといった不整合は起きない

2. Book の削除と Bulk Create が競合した場合
   - `ON DELETE RESTRICT` により、削除が先に成立した場合は Bulk Create が失敗する
   - 「削除済みの Book にノートだけ残る」状態は起こらない

※ 詳細なロック挙動や再実行ポリシーは Rails/PostgreSQL のデフォルトに委ねる。