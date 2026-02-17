class HardenNotesIntegrity < ActiveRecord::Migration[8.0]
  def change
      # ① page を NOT NULL にする前に不正データを防ぐ
      change_column_null :notes, :page, false

      # ② page >= 1 の CHECK 制約
      add_check_constraint :notes, "page >= 1", name: "notes_page_positive"
  
      # ③ 検索性能のための複合 index
      add_index :notes, [:book_id, :page], name: "index_notes_on_book_id_and_page"
  end
end
