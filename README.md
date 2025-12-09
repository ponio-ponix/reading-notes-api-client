# reading-notes

本の引用・メモを溜めて検索できる「読書ノート」アプリ。

- Backend: Ruby on Rails 8 (API モード + React/Vite)
- Frontend: React + TypeScript + Vite
- DB: PostgreSQL

## 構成

### Backend (Rails)

主な役割：

- 本（Book）とメモ（Note）の CRUD
- メモ検索（ページ範囲 / フリーテキスト）
- メモの一括登録（Bulk Create, トランザクションあり）

ディレクトリのざっくり役割：

- `app/controllers/api`  
  - `books_controller.rb` … 本の一覧・作成  
  - `notes_controller.rb` … 単体 Note の一覧・作成・検索  
  - `notes_bulk_controller.rb` … 一括作成エンドポイント
- `app/services/notes`  
  - `search_notes.rb` … 検索条件の正規化 + クエリ組み立て  
  - `bulk_create.rb` … Bulk Create のトランザクション処理
- `docs/`  
  - `01_api_contracts/` … Bulk Create などの API 契約  
  - `spec/` … 不変条件やデータモデルのメモ

### Frontend (React)

- 書籍一覧表示・選択
- 選択した本に対する Note の一覧・登録
- 今後：検索 UI / 連続メモ入力モードを実装予定

---

## 📘 Documentation

仕様や技術設計の詳細は `backend/docs/` にあります：

- **Bulk Create Notes API Contract**  
  `backend/docs/01_api_contracts/bulk_create_notes.md`

- **Invariants（不変条件）とトランザクション境界**  
  `backend/docs/spec/invariants.md`

- **Domain Model / Data Model**  
  `backend/docs/domain_model.md`  
  `backend/docs/spec/data_model.md`

- **MVP仕様**  
  `backend/docs/mvp_spec.md`

---

