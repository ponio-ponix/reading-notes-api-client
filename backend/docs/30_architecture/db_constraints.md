# DB Constraints (SSOT)

このドキュメントは **DB制約の単一の真実（SSOT）** とする。
実装の根拠は **db/schema.rb** と **db/migrate/** に置く。

## Summary

| 対象 | DB(schema) | Migration | 意図 | API/Model側の扱い | 備考 |
|---|---|---|---|---|---|
| books.title NOT NULL | schema: books.title null: false | 20260219104121_make_books_title_not_null.rb | Bookのタイトルは必須 | validates :title, presence: true | 既存NULLは空文字に変換後に制約追加 |
| notes.book_id NOT NULL | schema: notes.book_id null: false | 20251201064428_create_notes.rb | Noteは必ずBookに属する | belongs_to :book |  |
| FK notes.book_id → books.id (RESTRICT) | schema: add_foreign_key ... on_delete: :restrict | 20251215100955_change_notes_fk_on_delete_restrict.rb | Bookの物理削除でNoteを巻き込まない | Bookはソフトデリート運用 | RESTRICTで整合性維持 |
| notes.quote NOT NULL | schema: notes.quote null: false | 20251215101917_make_notes_quote_not_null.rb | 引用は必須 | validates :quote, presence: true |  |
| CHECK quote <= 1000 | schema: notes_quote_len | 20251215102003_add_notes_length_checks.rb | 過大入力をDBで拒否 | validates :quote, length <= 1000 |  |
| notes.memo NULL可 | schema: memo null許容 | (create_notes) | メモは任意 | allow_nil: true |  |
| CHECK memo <= 2000 (NULL OR) | schema: notes_memo_len | 20251215102003_add_notes_length_checks.rb | 任意入力だが上限は必要 | validates :memo, length <= 2000, allow_nil |  |
| notes.page NOT NULL | schema: notes.page null: false | 20260212033104_harden_notes_integrity.rb | ページは必須 | validates :page, presence: true | ※以前はNULL許容だった |
| CHECK page >= 1 | schema: notes_page_positive | 20260212033104_harden_notes_integrity.rb | 0/負数を拒否 | validates :page, numericality >= 1 |  |
| index notes(book_id) | schema: index_notes_on_book_id | (create_notes) | book_id検索用 | - | 複合indexで代替可の可能性あり |
| index notes(book_id, page) | schema: index_notes_on_book_id_and_page | 20260212033104_harden_notes_integrity.rb | book_id + page範囲検索用 | SearchNotesが利用 | EXPLAINで効果確認予定 |

## Notes
- `db/schema.rb` は DB現状の出力であり、変更は必ず migration で行う。
- 仕様変更（例: page NULL可→不可）の場合、関連ドキュメントとAPI仕様も追従させる。