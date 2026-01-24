require 'rails_helper'

RSpec.describe "Api::NotesController", type: :request do
  describe "POST /api/books/:book_id/notes" do
    let!(:book) { Book.create!(title: "Test Book", author: "Author") }

    context "when book exists" do
      it "creates a note and returns 201" do
        payload = { note: { page: 1, quote: "Test Quote", memo: "Test Memo" } }

        expect {
          post "/api/books/#{book.id}/notes", params: payload, as: :json
        }.to change { Note.count }.by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["quote"]).to eq("Test Quote")
      end
    end

    context "when book does not exist" do
      it "returns 404 when book does not exist" do
        post "/api/books/999999/notes",
             params: { note: { page: 1, quote: "Q" } },
             as: :json

        expect(response).to have_http_status(:not_found)
      end
    end

    context "when validation fails" do
      it "returns 422 when quote is blank after stripping whitespace" do
        post "/api/books/#{book.id}/notes",
             params: { note: { page: 1, quote: "   ", memo: "memo" } },
             as: :json

        expect(response).to have_http_status(:unprocessable_content)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_an(Array)
        expect(json["errors"]).not_to be_empty
      end
    end
  end

  describe "DELETE /api/notes/:id" do
    let!(:book) { Book.create!(title: "Test Book", author: "Author") }
    let!(:note) { book.notes.create!(page: 1, quote: "Test Quote", memo: "Test Memo") }

    context "when note exists" do
      it "deletes the note and returns 204" do
        expect {
          delete "/api/notes/#{note.id}"
        }.to change { Note.count }.by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when note does not exist" do
      it "returns 404 when note is not found" do
        delete "/api/notes/999999"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json["errors"]).to be_an(Array)
        expect(json["errors"]).not_to be_empty
      end
    end
  end
end
