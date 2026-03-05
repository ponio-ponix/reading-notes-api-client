module Api
  class BooksController < ApplicationController

    def index
      books = current_user.books.alive.order(created_at: :desc)
      render json: books.as_json(only: [:id, :title, :author])
    end

    def create
      book = current_user.books.new(book_params)
      book.save!
      render json: book.as_json(only: [:id, :title, :author]), status: :created
    end

    private

    def book_params
      params.require(:book).permit(:title, :author)
    end
  end
end