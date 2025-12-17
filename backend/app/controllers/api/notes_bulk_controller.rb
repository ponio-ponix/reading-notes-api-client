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

  # Request の形（notes が配列 / 要素が permit 可能）を HTTP 層で保証する。
  # 形が壊れている入力は 400（Bad Request）に落とし、業務ルールは Service に寄せる。

  def notes_params
    raw = params.require(:notes)
    raise ActionController::BadRequest, "notes must be an array" unless raw.is_a?(Array)
  
    raw.map.with_index do |note, i|
      raise ActionController::BadRequest, "notes[#{i}] must be an object" unless note.is_a?(ActionController::Parameters)
      note.permit(:page, :quote, :memo).to_h
    end
  end

end
