module Api
  class NotesSearchController < ApplicationController
    before_action :authenticate_user!, only: [:index]
    before_action :set_book, only: [:index]

    def index
      notes, meta = Notes::SearchNotes.call(
        book: @book,
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

    def set_book
      @book = current_user.books.alive.find(params[:book_id])
    end



  end
end
