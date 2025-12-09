# spec/services/notes/search_notes_spec.rb
require 'rails_helper'

RSpec.describe Notes::SearchNotes, type: :service do
  describe '.call' do
    let!(:book)  { Book.create!(title: "テスト本", author: "著者") }

    let!(:note1) do
      Note.create!(
        book:  book,
        page:  10,
        quote: "foo",
        memo:  "bar"
      )
    end

    let!(:note2) do
      Note.create!(
        book:  book,
        page:  20,
        quote: "baz",
        memo:  "qux"
      )
    end

    it '何もフィルタしないとき、全件・meta が正しい' do
      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     10
      )

      expect(notes.size).to eq 2
      expect(notes).to all(be_a(Note))

      expect(meta[:total_count]).to eq 2
      expect(meta[:page]).to        eq 1
      expect(meta[:limit]).to       eq 10
      expect(meta[:total_pages]).to eq 1
    end

    it 'query を指定するとその文字列を含むノートだけ返す' do
      notes, meta = described_class.call(
        book_id:   book.id,
        query:     "foo",
        page_from: nil,
        page_to:   nil,
        page:      1,
        limit:     10
      )

      expect(notes.size).to eq 1
      expect(notes.first).to eq note1
      expect(meta[:total_count]).to eq 1
    end

    it 'ページネーションが page / limit に従って動く' do
      8.times do |i|
        Note.create!(
          book:  book,
          page:  30 + i,
          quote: "extra #{i}",
          memo:  "m #{i}"
        )
      end

      notes, meta = described_class.call(
        book_id:   book.id,
        query:     nil,
        page_from: nil,
        page_to:   nil,
        page:      2,
        limit:     5
      )

      expect(meta[:total_count]).to eq 10
      expect(meta[:page]).to        eq 2
      expect(meta[:limit]).to       eq 5
      expect(meta[:total_pages]).to eq 2
      expect(notes.size).to         eq 5
    end
  end
end