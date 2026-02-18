class ApplicationController < ActionController::API
  rescue_from StandardError, with: :render_internal_error if Rails.env.production?

  rescue_from ApplicationErrors::BadRequest, with: :render_bad_request
  rescue_from ActionController::ParameterMissing, with: :render_bad_request

  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from Notes::BulkCreate::BulkInvalid, with: :render_bulk_unprocessable

  rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
  rescue_from ActiveRecord::RecordNotDestroyed, with: :render_unprocessable_entity

  # DB制約系（422で返す）
  rescue_from ActiveRecord::NotNullViolation, with: :render_db_constraint_violation
  rescue_from ActiveRecord::InvalidForeignKey, with: :render_db_constraint_violation
  rescue_from ActiveRecord::RecordNotUnique, with: :render_db_constraint_violation

  # CHECK違反（ある環境だけ）
  rescue_from ActiveRecord::CheckViolation, with: :render_db_constraint_violation if defined?(ActiveRecord::CheckViolation)


  private

  # DB制約系
  # 
  def render_db_constraint_violation(e)
    logger.warn "[422][DB] #{e.class}: #{e.message}"
    render json: { errors: ["DB constraint violated"] }, status: :unprocessable_entity
  end

  # アプリケーション側
  # 400 Bad Request
  def render_bad_request(e)
    logger.warn "[400] #{e.class}: #{e.message}"
    render json: { errors: [e.message] }, status: :bad_request
  end

  # 404 not found
  def render_not_found(e)
    logger.info "[404] #{e.class}: #{e.message}"
    render json: { errors: [e.message] }, status: :not_found
  end

  # 422 Unprocessable Entity（Bulk専用）
  def render_bulk_unprocessable(e)
    logger.info "[422] #{e.class}: #{e.errors}"
    render json: { errors: e.errors }, status: :unprocessable_entity
  end

  # 500 Internal Server Error
  def render_internal_error(e)
    logger.error "Internal Server Error: #{e.class} - #{e.message}"
    logger.error e.backtrace.join("\n") if e.backtrace.present?

    render json: { errors: ["Internal server error"] },
           status: :internal_server_error
  end

  def render_unprocessable_entity(e)
    record = e.record
    logger.info "[422] #{e.class}: #{record.class} #{record.errors.full_messages}"

    # errors.full_messages をそのまま配列で返す
    render json: { errors: record.errors.full_messages },
           status: :unprocessable_entity
  end
end