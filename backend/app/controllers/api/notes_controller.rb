module Api
  class NotesController < ApplicationController

    before_action :set_book, only: [:index, :create]

    def index
      notes, meta = Notes::SearchNotes.call(
        book_id:   @book.id,
        query:     params[:q],
        page_from: params[:page_from],
        page_to:   params[:page_to],
        page:      params[:page],   
        limit:     params[:limit]
      )
    
      render json: {
        notes: notes.as_json(
          only: [:id, :book_id, :page, :quote, :memo, :created_at]
        ),
        meta:  meta
      }
    end

    def create
      note = @book.notes.new(note_params)
      if note.save
        render json: note.as_json(
          only: [:id, :book_id, :page, :quote, :memo, :created_at]
        ), status: :created
      else
        render json: { errors: note.errors }, status: :unprocessable_entity
      end
    end

    def destroy
      note = Note.find_by(id: params[:id])
      return render json: { error: "Not found" }, status: :not_found unless note

      note.destroy
      head :no_content
    end

    private

    def set_book
      @book = Book.find_by(id: params[:book_id])
      unless @book
        render json: { error: "Book not found" }, status: :not_found
        return
      end
    end

    def note_params
      params.require(:note).permit(:page, :quote, :memo)
    end
  end
end