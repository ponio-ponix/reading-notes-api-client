class Api::UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:create]
  
  def create
    # has_secure_password により password を渡すと password_digest に保存される
    user = User.create!(users_params)
    render json: user.as_json(only: [:id, :name, :email]), status: :created
    
    
  end

  private
  def users_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
