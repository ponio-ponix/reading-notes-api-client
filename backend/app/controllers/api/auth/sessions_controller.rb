class Api::Auth::SessionsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false, only: [:create]

  def create
    email = params[:email].to_s
    password = params[:password].to_s
  
    return render_auth_unauthorized if email.blank? || password.blank?

    user = User.find_by(email: email)
    return render_auth_unauthorized unless user&.authenticate(password)

    raw = SecureRandom.hex(32)
    digest = digest_token(raw)

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

    scheme, raw = auth.split(" ", 2)
    return render_auth_unauthorized unless scheme == "Bearer"
    return render_auth_unauthorized if raw.blank?

    digest = digest_token(raw)
    token = AccessToken.active.find_by(token_digest: digest)
    return render_auth_unauthorized unless token

    token.update!(revoked_at: Time.current)
    render json: { ok: true }, status: :ok
  end

  def digest_token(raw)
    Digest::SHA256.hexdigest(raw)
  end
end