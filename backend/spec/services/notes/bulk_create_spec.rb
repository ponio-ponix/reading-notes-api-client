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
          described_class.call(book_id: book.id, notes_params: params)
        }.to raise_error(Notes::BulkCreate::BulkInvalid) { |e|
          expect(e.errors.size).to eq 1
          expect(e.errors.first[:index]).to eq 0
          expect(e.errors.first[:messages]).to include("Quote can't be blank")
        }
      
        expect(Note.where(book_id: book.id).count).to eq 0
      end
    end


    context "前提違反: notes が配列じゃないとき" do
      it "ArgumentError を投げ、1件も作成されない" do
        expect {
          described_class.call(book_id: book.id, notes_params: "x")
        }.to raise_error(ArgumentError, /notes must be a non-empty array/)

        expect(Note.where(book_id: book.id).count).to eq 0
      end
    end


    context "前提違反: book が存在しないとき" do
      it "ActiveRecord::RecordNotFound を投げ、1件も作成されない" do
        params = [{ page: 1, quote: "ok", memo: nil }]

        expect {
          described_class.call(book_id: 999_999, notes_params: params)
        }.to raise_error(ActiveRecord::RecordNotFound)

        expect(Note.where(book_id: book.id).count).to eq 0
      end
    end


    context "バリデーション失敗: 複数行が invalid のとき" do
      let(:params) do
        [
          { page: 10, quote: "",       memo: nil },        # index 0: quote blank
          { page: 11, quote: "ok",     memo: nil },        # index 1: ok
          { page: 12, quote: "ok",     memo: "b" * 2001 }  # index 2: memo too long
        ]
      end

      it "BulkInvalid を投げ、errors が複数要素で返る & 1件も作成されない" do
        expect {
          described_class.call(book_id: book.id, notes_params: params)
        }.to raise_error(Notes::BulkCreate::BulkInvalid) { |e|
          expect(e.errors.size).to eq 2

          # 順序に依存しないで検証（安全）
          by_index = e.errors.index_by { |h| h[:index] }

          expect(by_index.keys).to contain_exactly(0, 2)
          expect(by_index[0][:messages]).to include("Quote can't be blank")
          expect(by_index[2][:messages]).to include("Memo is too long (maximum is 2000 characters)")
        }

        expect(Note.where(book_id: book.id).count).to eq 0
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

    context "transaction が存在しないと壊れることを検知する" do
      before do
        # テスト中のみ、特定の quote で save! を失敗させる callback を追加
        Note.class_eval do
          before_save :fail_on_trigger_quote, prepend: true

          def fail_on_trigger_quote
            if quote == "TRIGGER_SAVE_FAILURE"
              raise ActiveRecord::RecordInvalid.new(self)
            end
          end
        end
      end

      after do
        Note.skip_callback(
          :save,
          :before,
          :fail_on_trigger_quote,
          prepend: true
        )
      end

      let(:params) do
        [
          { page: 1, quote: "valid quote 1", memo: nil },
          { page: 2, quote: "TRIGGER_SAVE_FAILURE", memo: nil },  # save! 時に失敗
          { page: 3, quote: "valid quote 3", memo: nil }
        ]
      end

      it "save! 失敗時に transaction が rollback し、DB に 1件も作成されない" do
        expect {
          begin
            described_class.call(book_id: book.id, notes_params: params)
          rescue ActiveRecord::RecordInvalid
            # save! の例外は想定内（無視）
          end
        }.not_to change { Note.count }
      end
    end
  end
end