# reading-notes (Backend API)

読書中の **引用（quote）/メモ（memo）** を **安全に保存・検索** できる Rails API。
**DB制約・一貫したエラーレスポンス・トランザクション整合性** を重視して実装。

## What this is

- **Books** を作成し、各Bookに紐づく **Notes**（quote/memo/page）を登録
- Notes の **検索**（キーワード / ページ範囲）
- Notes の **一括登録**（トランザクションで全成功/全失敗）

## Tech stack

- Ruby 3.2.2 / Rails 8.0.4 (API mode)
- PostgreSQL 16
- RSpec（`64 examples, 0 failures`）

## Design highlights (why it’s “safe”)

- **Soft delete**: Book は `deleted_at` による論理削除（履歴保持）
- **Referential integrity**: `notes.book_id → books.id` は **FK + ON DELETE RESTRICT**
  - Note がある Book の誤削除を防止
- **DB-level validation**: `quote <= 1000`, `memo <= 2000` を **CHECK 制約**で防御
- **Bulk create atomicity**: 一括登録はトランザクションで **全件成功 or 全件失敗**

## Quick start (Docker)

```bash
# Start
docker compose up --build

# Migrate (first time only)
docker compose exec web bin/rails db:migrate

```


## Smoke test
```bash
curl -i http://localhost:3000/api/books
```

---

## 📘 Documentation

API contract (SSOT): `backend/docs/40_api/api_overview.md`
仕様や技術設計の詳細は: `backend/README.md`

---

**本プロジェクトは、機能の多さよりもデータ整合性を優先し、小さくても信頼できるバックエンドAPIの実現を目的として設計しました。**

