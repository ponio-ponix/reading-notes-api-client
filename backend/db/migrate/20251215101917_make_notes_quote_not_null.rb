class MakeNotesQuoteNotNull < ActiveRecord::Migration[8.0]
  def change
    change_column_null :notes, :quote, false
  end
end