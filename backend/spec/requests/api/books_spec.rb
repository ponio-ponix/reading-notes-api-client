# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::Books", type: :request do
  let!(:user) do
    User.create!(
      email: "books1-spec-#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )
  end

  let!(:user2) do
    User.create!(
      email: "books2-spec-#{SecureRandom.hex(4)}@example.com",
      password: "password"
    )
  end

  before do
    stub_authentication(user)
  end

  describe "GET /api/books" do
    context "正常系" do
      it "returns 200 with an array" do
        Book.create!(user: user, title: "Book A", author: "Author A")
        Book.create!(user: user, title: "Book B", author: "Author B")

        get "/api/books"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to be_an(Array)
        expect(json.first).to include("id", "title", "author")
      end

      it "returns 200 with books ordered by created_at desc" do
        Book.create!(
          user: user,
          title: "Book A",
          author: "A",
          created_at: Time.zone.parse("2020-01-01 00:00:00")
        )
        Book.create!(
          user: user,
          title: "Book B",
          author: "B",
          created_at: Time.zone.parse("2020-01-02 00:00:00")
        )

        get "/api/books"

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json.map { _1.keys }).to all(include("id", "title", "author"))
        expect(json.map { _1["title"] }).to eq(["Book B", "Book A"])
      end

      it "認証済みユーザーのbookのみ返る" do
        book = Book.create!(
          user: user,
          title: "Book B",
          author: "B",
          created_at: Time.zone.parse("2020-01-02 00:00:00")
        )
        book2 = Book.create!(
          user: user2,
          title: "userBook 2",
          author: "user2",
          created_at: Time.zone.parse("2020-01-03 00:00:00")
        )
        get "/api/books"

        json = JSON.parse(response.body)
        ids = json.map { |book| book["id"] }

        expect(ids).to include(book.id)
        expect(ids).not_to include(book2.id)
      end

      it "（論理削除）認証済みユーザーが自分のbookを削除すると204を返し、その後一覧から除去されdeleted_atが入ること" do
        book = Book.create!(
          user: user,
          title: "Book C",
          author: "Mr.C",
          created_at: Time.zone.parse("2020-01-04 00:00:00")
        )

        get "/api/books"
        json = JSON.parse(response.body)
        
        expect(json.map{|n| n["title"]}).to include("Book C")
        
        id = book.id

        delete "/api/books/#{id}"
        delete_response_status = response.status

        expect(delete_response_status).to eq(204)
        
        get "/api/books"
        json = JSON.parse(response.body)


        expect(json.map{|n| n["title"]}).not_to include("Book C")

        deleted_book = user.books.find(id)
        expect(deleted_book.deleted_at).not_to be_nil

      end

      it "認証済みユーザーは他人のbookを削除できない" do
        anotherUserBook = Book.create!(
          user: user2,
          title: "another User Book",
          author: "Mr.another",
          created_at: Time.zone.parse("2020-01-05 00:00:00")
        )

        another_id = anotherUserBook.id

        delete "/api/books/#{another_id}"
        json2 = JSON.parse(response.body)

        expect(json2["error"]["code"]).to eq("not_found")

        expect(response.status).to eq(404)
        
        another_book = user2.books.alive.find(another_id)

        expect(another_book.deleted_at).to be_nil
        expect(Book.exists?(anotherUserBook.id)).to eq(true)

      end
    end

    context "異常系" do  

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
      expect(created.user_id).to eq(user.id)
    end

    it "returns 422 when invalid" do
      expect {
        post "/api/books",
             params: { book: { title: "", author: "Someone" } },
             as: :json
      }.not_to change(Book, :count)

      expect(response).to have_http_status(422)
      json = JSON.parse(response.body)

      expect(json.dig("error", "code")).to eq("unprocessable_entity")
      expect(json.dig("error", "message")).to eq("Validation failed")
      expect(json.dig("error", "details")).to include("Title can't be blank")
    end
  end
end