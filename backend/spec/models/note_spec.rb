require 'rails_helper'

RSpec.describe Note, type: :model do
  let(:book) { Book.create!(title: "Test Book", author: "Author") }
  subject(:note) { Note.new(book: book, quote: "quote", page: 1, memo: nil) }

  describe "validations" do
    it { should validate_presence_of(:quote) }
    it { should validate_length_of(:quote).is_at_most(1000) }
    it { should validate_length_of(:memo).is_at_most(2000) }
    it { should validate_numericality_of(:page).is_greater_than_or_equal_to(1) }
    it { should allow_value(nil).for(:memo) }
    it "is invalid without page" do
      note = Note.new(book: book, quote: "quote", page: nil, memo: nil)
      expect(note).to be_invalid
      expect(note.errors[:page]).to be_present
    end
  end

  describe "associations" do
    it { should belong_to(:book) }
  end

  describe "callbacks" do
    describe "#strip_text" do
      it "strips whitespace from quote and memo before validation" do
        book = Book.create!(title: "Test Book", author: "Author")
        note = book.notes.build(quote: "  test quote  ", memo: "  test memo  ", page: 1)

        note.valid?

        expect(note.quote).to eq("test quote")
        expect(note.memo).to eq("test memo")
      end
    end
  end
end
