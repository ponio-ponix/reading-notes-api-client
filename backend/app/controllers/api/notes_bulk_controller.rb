class Api::NotesBulkController < ApplicationController
  rescue_from Notes::BulkCreate::BulkInvalid, with: :render_bulk_invalid
  rescue_from ArgumentError, with: :render_bad_request

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

  def render_bulk_invalid(e)
    render json: {
      errors: [
        { index: e.index, messages: e.messages }
      ]
    }, status: :unprocessable_entity
  end

  def render_bad_request(e)
    render json: { errors: [e.message] }, status: :bad_request
  end
end
