class CreateNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :notes do |t|
      t.references :book, null: false, foreign_key: true
      t.integer :page
      t.text :quote
      t.text :memo

      t.timestamps
    end
  end
end
