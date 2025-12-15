class ChangeNotesFkOnDeleteRestrict < ActiveRecord::Migration[8.0]
  def change
    remove_foreign_key :notes, :books
    add_foreign_key :notes, :books, column: :book_id, on_delete: :restrict
  end
end