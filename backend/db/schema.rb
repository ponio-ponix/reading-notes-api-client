# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_02_19_104121) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "books", force: :cascade do |t|
    t.string "title", null: false
    t.string "author"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_books_on_deleted_at"
  end

  create_table "notes", force: :cascade do |t|
    t.bigint "book_id", null: false
    t.integer "page", null: false
    t.text "quote", null: false
    t.text "memo"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["book_id", "page"], name: "index_notes_on_book_id_and_page"
    t.index ["book_id"], name: "index_notes_on_book_id"
    t.check_constraint "char_length(quote) <= 1000", name: "notes_quote_len"
    t.check_constraint "memo IS NULL OR char_length(memo) <= 2000", name: "notes_memo_len"
    t.check_constraint "page >= 1", name: "notes_page_positive"
  end

  add_foreign_key "notes", "books", on_delete: :restrict
end
