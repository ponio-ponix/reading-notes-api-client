class Api::NotesBulkController < ApplicationController

  def create
    notes = Notes::BulkCreate.call(
      book_id: params[:book_id],
      notes_params: notes_params
    )

    render json: {
      notes: notes.as_json(only: [:id, :page, :quote, :memo, :created_at]),
      meta:  { created_count: notes.size }
    }, status: :created
  end

  private

  def notes_params
    # ここで Array を返すように揃える
    params.require(:notes).map do |note|
      note.permit(:page, :quote, :memo)
    end
  end

end
