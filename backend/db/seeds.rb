# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
book = Book.find_or_create_by!(title: "Sample Book") do |b|
  b.author = "Sample Author"
end

# 既存 book が author nil のケースも補正（任意だけど安全）
book.update!(author: "Sample Author") if book.author.nil?

12.times do |i|
  book.notes.find_or_create_by!(page: i + 1) do |n|
    n.quote = "引用 #{i + 1} のテキストです。"
    n.memo  = "メモ #{i + 1}"
  end
end