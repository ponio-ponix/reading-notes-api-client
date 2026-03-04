class Api::Auth::SessionsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false, only: [:create]

  def create
    email = params[:email].to_s
    password = params[:password].to_s

    user = User.find_by(email: email)
    return render_auth_unauthorized unless user&.authenticate(password)

    raw = SecureRandom.hex(32)
    digest = Digest::SHA256.hexdigest(raw)

    AccessToken.create!(
      user: user,
      token_digest: digest,
      expires_at: 30.days.from_now
    )

    render json: { token: raw }, status: :ok
  end

  def destroy
    # authenticate_user! は通っている前提（current_userはある）
    auth = request.headers["Authorization"].to_s.strip
    return render_auth_unauthorized unless auth.start_with?("Bearer ")

    raw = auth.delete_prefix("Bearer ").strip
    return render_auth_unauthorized if raw.empty?

    digest = Digest::SHA256.hexdigest(raw)
    token = AccessToken.active.find_by(token_digest: digest)
    return render_auth_unauthorized unless token

    token.update!(revoked_at: Time.current)
    render json: { ok: true }, status: :ok
  end
end