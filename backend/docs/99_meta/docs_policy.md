# Docs Policy（設計・API・雛形のズレ防止）

## 1. Docs の種類（役割の区分）

- **API契約（source of truth）**:
  - `docs/40_api/api_overview.md`
  - `docs/40_api/*_api.md`
  - `docs/40_api/api_contracts/**`
  - エンドポイント / リクエスト / レスポンス / ステータスコード
- **実装アウトライン（雛形）**: `docs/40_api/rails_impl_outline.md`
  - Rails 実装に落とすための雛形。**仕様ではない**
- **設計方針**: `docs/20_design/**`
  - soft-delete 等の方針・原則・例外ルール
- **例外 / エラー規約**: `docs/30_architecture/error_handling.md`
  - rescue_from / 例外クラス / HTTP変換 / 責務境界

---

## 2. 変更したら更新する Docs（対応表）

- **routes / controller / endpoint / response（外部仕様）を触った** → **API契約**を更新
  - `docs/40_api/api_overview.md`
  - `docs/40_api/*_api.md`
  - `docs/40_api/api_contracts/**`
- **controller責務・Service呼び出し形など“実装の型（雛形）”を触った** → `docs/40_api/rails_impl_outline.md`
- **soft-delete / スコープ / 削除方針** → `docs/20_design/soft_delete_policy.md`
- **rescue_from / 例外クラス / ステータス変換** → `docs/30_architecture/error_handling.md`
- **雛形のコード例（アウトライン）** → `docs/40_api/rails_impl_outline.md`

---

## 3. Docs のズレが起きた時のチェックリスト（順番固定）

1. `git grep "<該当path or endpoint>"`（例: `GET /api/books/:book_id/notes`）
2. `config/routes.rb` を確認（path → controller#action）
3. controller 実装を確認（action が存在するか）
4. service の責務を確認（alive チェックや存在確認の位置）
5. 修正順は **API契約 → 実装 → 雛形**（この順で直す）

---

## 4. 雛形コードのルール

- 雛形に Ruby コードを載せる場合は **コピペで成立する形**にする
- 成立しない場合は **「疑似コード」** と明記し、実行可能コードに見せない