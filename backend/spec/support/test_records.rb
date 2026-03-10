module TestRecords
  def create_user(email: "me@example.com")
    User.create!(email:, password: "password", password_confirmation: "password")
  end

  def create_book(user:, title: "Test Book", author: "Author")
    Book.create!(user:, title:, author:)
  end

  def create_note(user:, book:, page: 1, quote: "q", memo: "m")
    Note.create!(user:, book:, page:, quote:, memo:)
  end
end