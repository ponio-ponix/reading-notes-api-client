class Api::ExternalBookSearchesController < ApplicationController
  before_action :authenticate_user!
  
  def index
    if params[:query].blank?
      return render status: :bad_request
    end
    books = ExternalBooks::Search.call(query: params[:query])

    render json: books, status: :ok
  end
  
end

