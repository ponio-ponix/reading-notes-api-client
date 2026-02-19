class MakeBooksTitleNotNull < ActiveRecord::Migration[8.0]
  def up
    execute "UPDATE books SET title = '' WHERE title IS NULL"
    change_column_null :books, :title, false
  end

  def down
    change_column_null :books, :title, true
  end
end