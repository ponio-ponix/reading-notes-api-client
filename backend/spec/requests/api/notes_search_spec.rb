# spec/requests/api/notes_search_spec.rb
require "rails_helper"

RSpec.describe "Notes Search API", type: :request do
  describe "GET /api/books/:book_id/notes_search" do
    let!(:book) { Book.create!(title: "Test Book", author: "Author") }

    def json
      JSON.parse(response.body)
    end

    before do
      # 検索に引っかかる/引っかからない用に作っておく
      Note.create!(book: book, page: 1, quote: "hello world", memo: "m1")
      Note.create!(book: book, page: 2, quote: "ruby on rails", memo: "m2")
      Note.create!(book: book, page: 3, quote: "something else", memo: "m3")
    end

    context "正常系" do
      it "returns 200 and notes/meta" do
        get "/api/books/#{book.id}/notes_search", params: { q: "ruby", page: 1, limit: 10 }

        expect(response).to have_http_status(:ok)
        expect(json).to have_key("notes")
        expect(json).to have_key("meta")
        expect(json["notes"]).to be_an(Array)
        expect(json["meta"]).to be_a(Hash)

        # 少なくとも "ruby" を含むやつが返る想定（厳密な検索仕様はここでは縛りすぎない）
        returned_quotes = json["notes"].map { |n| n["quote"] }
        expect(returned_quotes.join(" ")).to include("ruby")
      end

      it "can filter by page range (page_from/page_to) when provided" do
        get "/api/books/#{book.id}/notes_search", params: { page_from: 2, page_to: 2, page: 1, limit: 10 }

        expect(response).to have_http_status(:ok)
        pages = json["notes"].map { |n| n["page"] }
        expect(pages).to all(eq(2))
      end
    end

    context "404系" do
      it "returns 404 when book does not exist" do
        get "/api/books/999999/notes_search", params: { q: "ruby" }

        expect(response).to have_http_status(:not_found)
      end

      it "returns 404 when book is soft-deleted" do
        book.update!(deleted_at: Time.current)

        get "/api/books/#{book.id}/notes_search", params: { q: "ruby" }

        expect(response).to have_http_status(:not_found)
      end
    end

    context "400系（ArgumentError rescue）" do
      it "returns 400 when page is not an integer" do
        get "/api/books/#{book.id}/notes_search", params: { page: "x" }

        expect(response).to have_http_status(:bad_request)
        expect(json["errors"]).to be_an(Array)
        expect(json["errors"]).not_to be_empty
      end

      it "returns 400 when limit is not an integer" do
        get "/api/books/#{book.id}/notes_search", params: { limit: "x" }

        expect(response).to have_http_status(:bad_request)
        expect(json["errors"]).to be_an(Array)
        expect(json["errors"]).not_to be_empty
      end

      it "returns 400 when page_from > page_to" do
        get "/api/books/#{book.id}/notes_search", params: { page_from: 3, page_to: 2 }

        expect(response).to have_http_status(:bad_request)
        expect(json["errors"]).to be_an(Array)
        expect(json["errors"]).not_to be_empty
      end
    end
  end
end