class Api::DebugController < ApplicationController
  rescue_from ActiveRecord::StatementInvalid, with: :render_statement_invalid

  def db_errors
    kind = params[:kind]

    case kind
    when "not_null"
      # NOT NULL違反を起こす（例：title が NOT NULL の books に null を入れる）
      Book.insert_all!([{ title: nil, created_at: Time.current, updated_at: Time.current }])
    when "check"
      # CHECK違反を起こす（例：page >= 1 的な制約があるnotesに 0 を入れる）
      now = Time.current
      bid = Book.first!.id
      Note.insert_all!([{
        page: 0,
        quote: "x",
        book_id: bid,
        created_at: now,
        updated_at: now
      }])
    when "fk"
      Note.insert_all!([{
        page: 1,
        quote: "x",
        book_id: 999999,
        created_at: Time.current,
        updated_at: Time.current
      }])
    when "unique"
      now = Time.current
      User.insert_all!([
        { email: "a@example.com", created_at: now, updated_at: now },
        { email: "a@example.com", created_at: now, updated_at: now }
      ])
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