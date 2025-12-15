# spec/services/notes/bulk_create_spec.rb
require "rails_helper"

RSpec.describe Notes::BulkCreate do
  let!(:book) { Book.create!(title: "Test Book", author: "Someone") }

  describe ".call" do
    context "正常系: 2件とも valid なとき" do
      let(:params) do
        [
          { page: 10, quote: "hello", memo: "test1" },
          { page: 11, quote: "world", memo: nil }
        ]
      end

      it "2件とも作成されて戻り値にも含まれる" do
        expect {
          result = described_class.call(book_id: book.id, notes_params: params)

          expect(result.size).to eq 2
          expect(result.map(&:quote)).to match_array %w[hello world]
          expect(result).to all be_a(Note)
        }.to change { Note.where(book_id: book.id).count }.by(2)
      end
    end

    context "バリデーション失敗: 1件目の quote が空のとき" do
      let(:params) do
        [
          { page: 10, quote: "",      memo: "test1" },
          { page: 11, quote: "world", memo: nil }
        ]
      end

      it "BulkInvalid を投げ、1件も作成されない" do
        expect {
          expect {
            described_class.call(book_id: book.id, notes_params: params)
          }.to raise_error(Notes::BulkCreate::BulkInvalid) { |e|
            expect(e.errors).to eq([
              {
                index: 0,
                messages: ["Quote can't be blank"]
              }
            ])
          }
        }.not_to change { Note.where(book_id: book.id).count }
      end
    end

    context "前提違反: notes が空配列のとき" do
      it "ArgumentError を投げ、1件も作成されない" do
        expect {
          expect {
            described_class.call(book_id: book.id, notes_params: [])
          }.to raise_error(ArgumentError, /must be a non-empty array/)
        }.not_to change { Note.where(book_id: book.id).count }
      end
    end

    context "前提違反: notes が MAX を超えるとき" do
      let(:over_params) do
        Array.new(Notes::BulkCreate::MAX_NOTES_PER_REQUEST + 1) do |i|
          { page: i + 1, quote: "q#{i}", memo: nil }
        end
      end

      it "ArgumentError を投げ、1件も作成されない" do
        expect {
          expect {
            described_class.call(book_id: book.id, notes_params: over_params)
          }.to raise_error(ArgumentError, /too many notes/)
        }.not_to change { Note.where(book_id: book.id).count }
      end
    end
  end
end