require "rails_helper"

RSpec.describe "Api::NotesController", type: :request do
  let!(:user) do
    User.create!(
      # name: "aaaa",
      email: "notes-spec-#{SecureRandom.hex(4)}@example.com",
      password: "password"
      # password_confirmation: "password"
    )
  end

  before do
    stub_authentication(user)
  end

  let!(:book) { Book.create!(user: user, title: "Test Book", author: "Author") }
  let!(:book3) { Book.create!(user: user, title: "Test Book3", author: "Author3") }
  let!(:note) { Note.create!(book: book, page: 1, quote: "Good quote", memo: "memo") }
  let!(:note3) { Note.create!(book: book3, page: 1, quote: "Good quote3", memo: "memo3") }

  let!(:user2) { User.create!(email: "notes-spec2-#{SecureRandom.hex(4)}@example.com", password: "password") }
  let!(:book2) { Book.create!(user: user2, title: "Test Book2", author: "Author2") }
  let!(:note2) { Note.create!(book: book2, page: 1, quote: "Good quote2", memo: "memo2") }

  describe "POST /api/books/:book_id/notes" do
    context "正常系" do
      it "自分のBookにNoteを作成した場合、201を返し、Note件数が1件増える" do
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

    context "所有権境界" do
      it "他人のBook IDを指定した場合、404を返し、Note件数が増えない" do
        # 404を返す
        # Note件数が増えない
        expect{
          post "/api/books/#{book2.id}/notes",
          params: { note: { page: 1, quote: "Good quote", memo: "memo" } },
          as: :json
        }.to_not change { Note.count }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "リソース境界" do
      #直す
      it "存在しないBook IDを指定した場合、404を返し、Note件数が増えない" do
        expect { post "/api/books/999999/notes",
             params: { note: { page: 1, quote: "Good quote", memo: "memo" } },
             as: :json }.not_to change{ Note.count}

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json.dig("error", "code")).to eq("not_found")
        expect(json.dig("error", "message")).to eq("Resource not found")
      end

      it "論理削除済みBook IDを指定した場合、404を返し、Note件数が増えない" do
        # 404を返す
        # Note件数が増えない
        delete "/api/books/#{book.id}"
        get "/api/books"
        json = JSON.parse(response.body)

        json.each do |m|
          id = m["id"]
          expect(id).not_to eq(book.id)
        end

        expect { post "/api/books/#{book.id}/notes",
             params: { note: { page: 1, quote: "Good quote", memo: "memo" } },
             as: :json }.not_to change{ Note.count}
        expect(response).to have_http_status(:not_found)
      
      end
    end

    context "入力境界（Validation）" do
      it "quoteが空白のみの場合、422を返し、Note件数が増えない" do
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

  describe "DELETE /api/books/:book_id/notes/:id" do

    context "正常系" do
      it "自分のBookに属するNoteを削除すると204を返し、Noteが削除される" do
        expect {
          delete "/api/books/#{book.id}/notes/#{note.id}"
        }.to change(Note, :count).by(-1)

        expect(response).to have_http_status(:no_content)
      end

    end

    context "所有権境界" do
      it "他人のBook配下にあるNoteを指定した場合、404を返し、Noteが削除されない" do
        expect {
          delete "/api/books/#{book2.id}/notes/#{note2.id}"
        }.not_to change{ Note.count }
        expect(response).to have_http_status(:not_found)
      end
    end
    
    context "リソース境界" do
      it "存在しないNoteでは404を返し、Noteが削除されない" do
        expect {
          delete "/api/books/#{book.id}/notes/99999999"
        }.not_to change{Note.count}

        expect(response).to have_http_status(:not_found)
        json = JSON.parse(response.body)
        expect(json.dig("error", "code")).to eq("not_found")
        expect(json.dig("error", "message")).to eq("Resource not found")
      end
      it "自分のBook AのURLに、自分のBook Bに属するNote IDを指定した場合、404を返し、Noteが削除されない" do
        expect {
          delete "/api/books/#{book.id}/notes/#{note3.id}"
        }.not_to change{Note.count}
        expect(response).to have_http_status(:not_found)
      end
    
      it "論理削除済みBook配下のNoteを指定した場合、404を返し、Noteが削除されない" do
        expect {
          delete "/api/books/#{book.id}"
        }.not_to change{ Note.count }

        expect {
          delete "/api/books/#{book.id}/notes/#{note.id}"
        }.not_to change{ Note.count }

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
