module Api
  class BooksController < ApplicationController

    def index
      books = Book.alive.order(created_at: :desc)
      render json: books.as_json(only: [:id, :title, :author])
    end

    def create
      book = Book.new(book_params)
      if book.save
        render json: book.as_json(only: [:id, :title, :author]), status: :created
      else
        render json: { errors: book.errors }, status: :unprocessable_entity
      end
    end

    private

    def book_params
      params.require(:book).permit(:title, :author)
    end
  end
end