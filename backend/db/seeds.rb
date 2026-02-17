# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
#   
return if Rails.env.test?

book = Book.first || Book.create!(title: "Seed Book", author: "Seed Author")

12.times do |i|
  book.notes.find_or_create_by!(page: i + 1) do |note|
    note.quote = "引用 #{i + 1} のテキストです。"
    note.memo  = "メモ #{i + 1}"
  end
end