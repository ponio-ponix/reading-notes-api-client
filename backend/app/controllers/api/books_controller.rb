module Api
  class BooksController < ApplicationController
    before_action :authenticate_user!

    def index
      books = current_user.books.alive.order(created_at: :desc)
      render json: books.as_json(only: [:id, :title, :author])
    end

    def create
      book = current_user.books.new(book_params)
      book.save!
      render json: book.as_json(only: [:id, :title, :author]), status: :created
    end

    def destroy
      book = current_user.books.alive.find(params[:id])
      book.update(deleted_at: Time.current)
      head :no_content
    end

    private

    def book_params
      params.require(:book).permit(:title, :author)
    end
  end
end