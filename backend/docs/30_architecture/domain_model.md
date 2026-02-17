
### 3. domain_model.md

```bash
cat > docs/domain_model.md << 'EOF'

```
## 1. ドメイン概要

このアプリのコアドメインは「読書中の引用メモ」。

登場する主な概念:

- Book（本）
- Note（引用ノート）
- Tag（タグ）
- NoteTag（ノートとタグの中間テーブル）

MVPではユーザーは1人想定（Userテーブルは後回し）。

---

## 2. ER 図イメージ（テキスト）

- Book (1) —— (N) Note
- Note (N) —— (N) Tag（NoteTagで多対多）

---

## 3. エンティティ定義（テーブル案）

### 3.1 books テーブル

| カラム名    | 型        | 制約                       | 説明         |
|------------|-----------|----------------------------|--------------|
| id         | bigint PK | NOT NULL                   | 識別子       |
| title      | varchar   | NOT NULL                   | 本のタイトル |
| author     | varchar   | NULL 可                    | 著者名       |
| created_at | timestamp | NOT NULL                   | 作成日時     |
| updated_at | timestamp | NOT NULL                   | 更新日時     |

インデックス:
- `index_books_on_deleted_at`

---

### 3.2 notes テーブル

| カラム名    | 型        | 制約                       | 説明                      |
|------------|-----------|----------------------------|---------------------------|
| id         | bigint PK | NOT NULL                   | 識別子                    |
| book_id    | bigint FK | NOT NULL, references books (on_delete: :restrict) | 紐づく本                  |
| page       | integer   | NOT NULL, CHECK (page >= 1) | ページ番号                |
| quote      | text      | NOT NULL, CHECK (char_length <= 1000) | 引用テキスト（最大1000文字） |
| memo       | text      | NULL 可, CHECK (char_length <= 2000)  | 自分のメモ（最大2000文字）   |
| created_at | timestamp | NOT NULL                   | 作成日時                  |
| updated_at | timestamp | NOT NULL                   | 更新日時                  |

インデックス:
- `index_notes_on_book_id`
- `index_notes_on_book_id_and_page`

---

### 3.3 tags テーブル

| カラム名    | 型        | 制約             | 説明   |
|------------|-----------|------------------|--------|
| id         | bigint PK | NOT NULL         | 識別子 |
| name       | varchar   | NOT NULL, UNIQUE | タグ名 |
| created_at | timestamp | NOT NULL         | 作成日時 |
| updated_at | timestamp | NOT NULL         | 更新日時 |

インデックス:
- `index_tags_on_name` (UNIQUE)

---

### 3.4 note_tags テーブル（中間）

| カラム名    | 型        | 制約                               | 説明     |
|------------|-----------|------------------------------------|----------|
| id         | bigint PK | NOT NULL                           | 識別子   |
| note_id    | bigint FK | NOT NULL, references notes         | ノートID |
| tag_id     | bigint FK | NOT NULL, references tags          | タグID   |
| created_at | timestamp | NOT NULL                           | 作成日時 |

インデックス:
- `index_note_tags_on_note_id`
- `index_note_tags_on_tag_id`
- `index_note_tags_on_note_id_and_tag_id` (UNIQUE)  → 同じノートに同じタグを二重登録しないため

---

## 4. ドメインルール（簡易メモ）

- Book
  - `title` は必須
  - 同じタイトルが複数あっても許容（著者が違う場合など）
- Note
  - `quote` は必須
  - `page` は必須・整数・1以上（DB CHECK 制約）
- Tag
  - `name` は必須・ユニーク
  - 小文字化・前後スペース除去など正規化してもよい
- NoteTag
  - `(note_id, tag_id)` の組み合わせはユニーク

---

## 5. 将来の拡張を意識したメモ

- User を追加する場合:
  - `users` テーブルを増やし、
  - `books.user_id` を持たせる（ユーザーごとに本とノートを分ける）
- 認証:
  - `session_tokens` テーブル or JWT
- メモの「重要度」や「再読フラグ」などは `notes` にカラム追加で対応可能
EOF