class Api::UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create]
  
  def create
    
    email = params[:email]
    password = params[:password]

    # has_secure_password により password を渡すと password_digest に保存される
    User.create!(email: email, password: password)
    # 
    render json: {text: "ok"}, status: :created
    
  end
end
