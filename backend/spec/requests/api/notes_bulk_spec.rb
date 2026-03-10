require 'rails_helper'

RSpec.describe "POST /api/books/:book_id/notes/bulk", type: :request do
  let!(:user) do
    User.create!(
      email: "note-spec-#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )
  end
  
  before do
    stub_authentication(user)
  end

  let!(:book) { Book.create!(user: user, title: "Test Book", author: "Author") }

  describe "成功ケース → 201 を返す" do
    context "when all notes are valid" do
      it "creates notes and returns 201" do
        payload = {
          notes: [
            { page: 1, quote: "Q1", memo: "M1" },
            { page: 2, quote: "Q2", memo: "M2" }
          ]
        }

        expect {
          post "/api/books/#{book.id}/notes/bulk", params: payload, as: :json
        }.to change { Note.count }.by(2)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["notes"].size).to eq(2)
      end
    end
  end
  
  describe "404 を返す" do
    it "returns 404 when book is soft-deleted" do
      book.update!(deleted_at: Time.current)
    
      expect {
        post "/api/books/#{book.id}/notes/bulk",
             params: { notes: [{ page: 1, quote: "q", memo: "m" }] },
             as: :json
      }.not_to change { Note.count }
    
      expect(response).to have_http_status(:not_found)
    end
    it "returns 404 when book does not exist" do
      expect {
        post "/api/books/999_999/notes/bulk",
             params: { notes: [{ page: 1, quote: "q", memo: "m" }] },
             as: :json
      }.not_to change { Note.count }
  
      expect(response).to have_http_status(:not_found)
    end
  end
  describe "BulkInvalid → 422 + rollback を検知する" do
    let(:payload) do
      {
        notes: [
          { page: 10, quote: "valid quote 1", memo: "memo 1" },
          { page: 11, quote: "",              memo: "memo 2" },  # invalid: quote blank
          { page: 12, quote: "valid quote 3", memo: "memo 3" }
        ]
      }
    end

    it "HTTP 422 を返し、レスポンスが BulkInvalid 形式で、DB に 1件も作成されない" do
      expect {
        post "/api/books/#{book.id}/notes/bulk", params: payload, as: :json
      }.not_to change { Note.count }

      expect(response).to have_http_status(:unprocessable_content)

      json = JSON.parse(response.body, symbolize_names: true)

      expect(json).to have_key(:error)
      expect(json[:error]).to be_a(Hash)
      expect(json[:error][:code]).to eq("unprocessable_entity")
      expect(json[:error][:message]).to eq("Validation failed")
      expect(json[:error][:details]).to be_an(Array)
      expect(json[:error][:details]).not_to be_empty

      # BulkInvalid 形式: [{ index: N, messages: [...] }]
      first_error = json[:error][:details].first
      expect(first_error).to have_key(:index)
      expect(first_error).to have_key(:messages)
      expect(first_error[:messages]).to be_an(Array)
    end
  end

  describe "BadRequest → 400 を返す" do
    it "notes が nil のとき 400 を返す (DB変化なし)" do
      expect {
        post "/api/books/#{book.id}/notes/bulk", params: {}, as: :json
      }.not_to change { Note.count }

      expect(response).to have_http_status(:bad_request)

      json = JSON.parse(response.body)
      expect(json["error"]).to be_a(Hash)
      expect(json["error"]["code"]).to eq("bad_request")
      expect(json["error"]["message"]).to eq("Bad request")
    end

    it "notes が配列じゃない → 400 'notes must be an array' (DB変化なし)" do
      expect {
        post "/api/books/#{book.id}/notes/bulk", params: { notes: "invalid" }, as: :json
      }.not_to change { Note.count }

      expect(response).to have_http_status(:bad_request)

      json = JSON.parse(response.body)
      expect(json["error"]).to be_a(Hash)
      expect(json["error"]["code"]).to eq("bad_request")
      expect(json["error"]["message"]).to eq("Bad request")
    end

    it "element が object じゃない → 400 'notes[0] must be an object' (DB変化なし)" do
      expect {
        post "/api/books/#{book.id}/notes/bulk", params: { notes: ["string"] }, as: :json
      }.not_to change { Note.count }

      expect(response).to have_http_status(:bad_request)

      json = JSON.parse(response.body)
      expect(json["error"]).to be_a(Hash)
      expect(json["error"]["code"]).to eq("bad_request")
      expect(json["error"]["message"]).to eq("Bad request")
    end
  end

  describe "二重クエリ回帰テスト" do
    it "Book の SELECT は1回だけ（bulk）" do
      payload = { notes: [{ page: 1, quote: "q", memo: "m" }] }
  
      book_selects = QueryCounter.count_book_selects do
        post "/api/books/#{book.id}/notes/bulk", params: payload, as: :json
      end
  
      expect(book_selects).to eq(1)
    end
  end
end
