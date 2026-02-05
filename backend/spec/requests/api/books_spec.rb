# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Books", type: :request do
  describe "GET /api/books" do
    it "returns 200 with an array" do
      Book.create!(title: "Book A", author: "Author A")
      Book.create!(title: "Book B", author: "Author B")

      get "/api/books"

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first).to include("id", "title", "author")
    end
    it "returns 200 with books ordered by created_at desc" do
      Book.create!(title: "Book A", author: "A", created_at: Time.zone.parse("2020-01-01 00:00:00"))
      Book.create!(title: "Book B", author: "B", created_at: Time.zone.parse("2020-01-02 00:00:00"))
    
      get "/api/books"
    
      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.map { _1.keys }).to all(include("id", "title", "author"))
      expect(json.map { _1["title"] }).to eq(["Book B", "Book A"])

    end
  end

  describe "POST /api/books" do
    it "returns 201 with created book when valid" do
      expect {
        post "/api/books",
             params: { book: { title: "New Book", author: "Someone" } },
             as: :json
      }.to change(Book, :count).by(1)

      expect(response).to have_http_status(:created)
      json = JSON.parse(response.body)
      expect(json).to include("id", "title", "author")
      expect(json["title"]).to eq("New Book")

      created = Book.find(json["id"])
      expect(created.title).to eq("New Book")
      expect(created.author).to eq("Someone")
    end

    it "returns 422 with errors array when invalid" do
      expect {
        post "/api/books",
             params: { book: { title: "", author: "Someone" } },
             as: :json
      }.not_to change(Book, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      json = JSON.parse(response.body)
      expect(json["errors"]).to be_an(Array)
      expect(json["errors"]).to include("Title can't be blank")
    end
  end
end