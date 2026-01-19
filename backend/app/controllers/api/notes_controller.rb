module Api
  class NotesController < ApplicationController

    before_action :set_book, only: [:create]

    def create
      note = @book.notes.create!(note_params)
      render json: note.as_json(only: [:id, :book_id, :page, :quote, :memo, :created_at]),
             status: :created
    end

    def destroy
      note = Note.find(params[:id])
      note.destroy!
      head :no_content
    end

    private

    def set_book
      @book = Book.alive.find(params[:book_id])
    end

    def note_params
      params.require(:note).permit(:page, :quote, :memo)
    end
  end
end