# Soft Delete Policy (Books)

## 方針
- Book は物理削除しない（DELETE / Book.destroy / delete は提供しない）
- Book の削除は論理削除とし、`deleted_at` に削除時刻を記録する（NULL 可）
- 通常の取得（一覧 / 詳細 / 検索）は **削除されていない Book のみ**を対象とする  
  - 条件：`deleted_at IS NULL`

## API / ユースケースの扱い
- `deleted_at` が設定された Book は「存在しない扱い」とする
  - Book の参照（詳細取得 / 検索）: **404 Not Found**
  - Note の作成 / 検索: **404 Not Found**
- 理由：
  - 削除済みリソースはクライアントから見て「存在しない」のが自然
  - API の分岐が単純になり、実装と運用が安定する

## DB / Rails の整合
- 外部キーは `on_delete: :restrict` を維持する  
  - `notes.book_id -> books.id (RESTRICT)`
- Rails の関連（`dependent`）は DB の RESTRICT 方針に揃える（後続対応）
  - 現状の `dependent: :destroy` は方針と矛盾するため、将来的に解消する

## スコープ方針
- `default_scope` は使用しない（暗黙条件の漏れ・意図しない副作用を避けるため）
- 取得は明示的な scope を使う（例：`Book.active`）