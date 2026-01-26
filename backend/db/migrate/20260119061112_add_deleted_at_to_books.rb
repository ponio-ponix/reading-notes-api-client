class AddDeletedAtToBooks < ActiveRecord::Migration[8.0]
  def change
    add_column :books, :deleted_at, :datetime, null: true
    add_index  :books, :deleted_at
  end
end
