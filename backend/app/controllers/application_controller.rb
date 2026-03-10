require "digest"

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

  before_action :authenticate_user!

  private

  def render_error(code:, message:, status:, details: nil)
    payload = { error: { code: code, message: message } }
    payload[:error][:details] = details if !details.nil?
    render json: payload, status: status
  end

  attr_reader :current_user

  def render_auth_unauthorized
    render_error(code: "unauthorized", message: "Authentication required", status: :unauthorized)
  end

  def authenticate_user!
    auth = request.headers["Authorization"].to_s.strip
    scheme, raw = auth.split(" ", 2)
  
    unless scheme&.casecmp?("Bearer")
      logger.info("[401] missing/invalid bearer scheme")
      return render_auth_unauthorized
    end
  
    if raw.blank?
      logger.info("[401] empty token")
      return render_auth_unauthorized
    end
  
    digest = digest_token(raw)
    token = AccessToken.active.find_by(token_digest: digest)
  
    unless token
      logger.info("[401] token not found / inactive")
      return render_auth_unauthorized
    end
  
    @current_user = token.user
  end

  def digest_token(raw)
    Digest::SHA256.hexdigest(raw)
  end

  # DB制約系
  # 
  def render_db_constraint_violation(e)
    logger.warn "[422][DB] #{e.class}: #{e.message}"
  
    render_error(
      code: "db_constraint_violation",
      message: "DB constraint violated",
      status: :unprocessable_entity
    )
  end

  # アプリケーション側
  # 400 Bad Request
  def render_bad_request(e)
    logger.warn "[400] #{e.class}: #{e.message}"
    render_error(code: "bad_request", message: "Bad request", status: :bad_request)
  end

  # 404 not found
  def render_not_found(_e)
    logger.info "[404] RecordNotFound"
    render_error(code: "not_found", message: "Resource not found", status: :not_found)
  end

  # 422 Unprocessable Entity（Bulk専用）
  def render_bulk_unprocessable(e)
    logger.info "[422] BulkInvalid #{e.errors}"
  
    render_error(
      code: "unprocessable_entity",
      message: "Validation failed",
      status: :unprocessable_entity,
      details: e.errors
    )
  end

  # 500 Internal Server Error
  def render_internal_error(e)
    logger.error "Internal Server Error: #{e.class} - #{e.message}"
    logger.error e.backtrace.join("\n") if e.backtrace.present?
  
    render_error(code: "internal_server_error", message: "Internal server error", status: :internal_server_error)
  end

  def render_unprocessable_entity(e)
    record = e.record
    logger.info "[422] #{record.class} #{record.errors.full_messages}"
  
    render_error(
      code: "unprocessable_entity",
      message: "Validation failed",
      status: :unprocessable_entity,
      details: record.errors.full_messages
    )
  end
end