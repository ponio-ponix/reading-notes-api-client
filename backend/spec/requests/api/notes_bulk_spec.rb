require 'rails_helper'

RSpec.describe "POST /api/books/:book_id/notes/bulk", type: :request do
  let!(:book) { Book.create!(title: "Test Book", author: "Author") }

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

      post "/api/books/#{book.id}/notes/bulk",
        params: {
          notes: [
            { page: 1, quote: "q", memo: "m" }
          ]
        },
        as: :json

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

      expect(response).to have_http_status(:unprocessable_entity)

      json = JSON.parse(response.body, symbolize_names: true)
      expect(json).to have_key(:errors)
      expect(json[:errors]).to be_an(Array)
      expect(json[:errors].size).to be >= 1

      # BulkInvalid 形式: [{ index: N, messages: [...] }]
      first_error = json[:errors].first
      expect(first_error).to have_key(:index)
      expect(first_error).to have_key(:messages)
      expect(first_error[:messages]).to be_an(Array)
    end
  end

  describe "ArgumentError → 400 を返す" do
    context "notes が空配列のとき" do
      let(:payload) { { notes: [] } }

      it "HTTP 400 を返し、レスポンスが errors 配列形式で、DB に 1件も作成されない" do
        expect {
          post "/api/books/#{book.id}/notes/bulk", params: payload, as: :json
        }.not_to change { Note.count }

        expect(response).to have_http_status(:bad_request)

        json = JSON.parse(response.body, symbolize_names: true)
        expect(json).to have_key(:errors)
        expect(json[:errors]).to be_an(Array)
        expect(json[:errors].size).to be >= 1
        expect(json[:errors].first).to be_a(String)
      end
    end
  end

  
end
