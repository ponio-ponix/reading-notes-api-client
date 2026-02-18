class Api::DebugController < ApplicationController
  rescue_from ActiveRecord::StatementInvalid, with: :render_statement_invalid

  def db_errors
    kind = params[:kind]

    case kind
    when "not_null"
      # NOT NULL違反を起こす（例：title が NOT NULL の books に null を入れる）
      Book.create!(title: nil)
    when "check"
      # CHECK違反を起こす（例：page >= 1 的な制約があるnotesに 0 を入れる）
      Note.create!(page: 0, quote: "x", book_id: 1)
    when "fk"
      # FK違反を起こす（存在しない book_id）
      Note.create!(page: 1, quote: "x", book_id: 999999)
    when "unique"
      # UNIQUE違反（同じ値2回）
      User.create!(email: "a@example.com")
      User.create!(email: "a@example.com")
    else
      render json: { errors: ["unknown kind"] }, status: :bad_request
    end

    render json: { ok: true } # ここには基本来ない（例外で rescue される）
  end

  def render_statement_invalid(e)
    cause = e.cause
    if cause.is_a?(PG::CheckViolation) ||
       cause.is_a?(PG::NotNullViolation) ||
       cause.is_a?(PG::ForeignKeyViolation) ||
       cause.is_a?(PG::UniqueViolation)
      render json: { errors: ["DB constraint violated"] }, status: :unprocessable_entity
    else
      raise
    end
  end

  private
end