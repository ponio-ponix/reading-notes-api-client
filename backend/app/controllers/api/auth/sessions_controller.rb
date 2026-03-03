class Api::Auth::SessionsController < ApplicationController
  skip_before_action :authenticate_user!, raise: false

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
end