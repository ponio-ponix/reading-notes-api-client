# frozen_string_literal: true

class HealthController < ActionController::API
  def show
    render json: { ok: true }
  end

  def root
    render json: {
      service: "Reading Notes Backend API",
      status: "ok",
      health: "/healthz"
    }
  end
end