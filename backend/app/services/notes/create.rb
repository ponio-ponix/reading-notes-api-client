module Notes
  class Create
    def self.call(book_id:, page:, quote:, memo:)
      book = Book.find(book_id)
      book.notes.create!(
        page:  page,
        quote: quote,
        memo:  memo
      )
    end
  end
end