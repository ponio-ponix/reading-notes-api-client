class AddNotesLengthChecks < ActiveRecord::Migration[8.0]
  def change
    add_check_constraint :notes, "char_length(quote) <= 1000", name: "notes_quote_len"
    add_check_constraint :notes, "memo IS NULL OR char_length(memo) <= 2000", name: "notes_memo_len"
  end
end