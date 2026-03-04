class MakeBookUserIdNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :books, :user_id, false
  end
end