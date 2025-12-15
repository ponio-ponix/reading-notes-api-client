class ApplicationController < ActionController::API
  rescue_from ArgumentError, with: :render_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from Notes::BulkCreate::BulkInvalid, with: :render_bulk_unprocessable
  rescue_from StandardError, with: :render_internal_error if Rails.env.production?
  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity

  private

  # 400 Bad Request
  def render_bad_request(e)
    render json: { errors: [e.message] }, status: :bad_request
  end

  # 404 not found
  def render_not_found(e)
    render json: { errors: [e.message] }, status: :not_found
  end

  # 422 Unprocessable Entity（Bulk専用）
  def render_bulk_unprocessable(e)
    render json: { errors: e.errors }, status: :unprocessable_entity
  end

  # 500 Internal Server Error
  def render_internal_error(e)
    render json: { errors: ["Internal server error"] },
           status: :internal_server_error
  end

  def render_unprocessable_entity(e)
    record = e.record

    # errors.full_messages をそのまま配列で返す
    render json: { errors: record.errors.full_messages },
           status: :unprocessable_entity
  end
end