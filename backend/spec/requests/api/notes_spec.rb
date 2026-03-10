require "rails_helper"

RSpec.describe "Api::NotesController", type: :request do
  let!(:user) do
    User.create!(
      email: "notes-spec-#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )
  end

  before do
    stub_authentication(user)
  end

  let!(:book) { Book.create!(user: user, title: "Test Book", author: "Author") }

  describe "POST /api/books/:book_id/notes" do
    context "when book exists" do
      it "creates a note and returns 201" do
        expect {
          post "/api/books/#{book.id}/notes",
               params: { note: { page: 1, quote: "Good quote", memo: "memo" } },
               as: :json
        }.to change(Note, :count).by(1)

        expect(response).to have_http_status(:created)
        json = JSON.parse(response.body)
        expect(json["book_id"]).to eq(book.id)
        expect(json["page"]).to eq(1)
        expect(json["quote"]).to eq("Good quote")
        expect(json["memo"]).to eq("memo")
      end
    end

    context "when book does not exist" do
      it "returns 404 when book does not exist" do
        post "/api/books/999999/notes",
             params: { note: { page: 1, quote: "Good quote", memo: "memo" } },
             as: :json

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json.dig("error", "code")).to eq("not_found")
        expect(json.dig("error", "message")).to eq("Resource not found")
      end
    end

    context "when validation fails" do
      it "returns 422 when quote is blank after stripping whitespace" do
        expect {
          post "/api/books/#{book.id}/notes",
               params: { note: { page: 1, quote: "   ", memo: "memo" } },
               as: :json
        }.not_to change(Note, :count)

        expect(response).to have_http_status(422)
        json = JSON.parse(response.body)
        expect(json.dig("error", "code")).to eq("unprocessable_entity")
        expect(json.dig("error", "message")).to eq("Validation failed")
        expect(json.dig("error", "details")).to include("Quote can't be blank")
      end
    end
  end

  describe "DELETE /api/notes/:id" do
    let!(:note) { Note.create!(book: book, page: 1, quote: "Good quote", memo: "memo") }

    context "when note exists" do
      it "deletes the note and returns 204" do
        expect {
          delete "/api/notes/#{note.id}"
        }.to change(Note, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end
    end

    context "when note does not exist" do
      it "returns 404 when note is not found" do
        delete "/api/notes/999999"

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json.dig("error", "code")).to eq("not_found")
        expect(json.dig("error", "message")).to eq("Resource not found")
      end
    end
  end
end