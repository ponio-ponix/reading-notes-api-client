class Api::NotesBulkController < ApplicationController

  before_action :set_book, only: [:create]

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

  # HTTP レイヤで Request の形だけをチェックする。
  # notes が配列であること、各要素が permit できる形であることを保証する。
  #
  # 形が壊れている場合は例外を投げ、
  # 400 にするかどうかなどの HTTP レスポンスは
  # ApplicationController 側の rescue に任せる。
  #
  # バリデーションや一括作成のルールは Service に寄せる。

  def notes_params
    raw = params[:notes]
    raise ApplicationErrors::BadRequest, "notes must be provided" if raw.nil?
    raise ApplicationErrors::BadRequest, "notes must be an array" unless raw.is_a?(Array)
  
    raw.map.with_index do |note, i|
      raise ApplicationErrors::BadRequest, "notes[#{i}] must be an object" unless note.is_a?(ActionController::Parameters)
      note.permit(:page, :quote, :memo).to_h
    end
  end

  def set_book
    @book = Book.alive.find(params[:book_id])
  end

end
