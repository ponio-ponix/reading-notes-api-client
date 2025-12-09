require 'rails_helper'

RSpec.describe "Api::NotesBulks", type: :request do
  describe "GET /create" do
    it "returns http success" do
      get "/api/notes_bulk/create"
      expect(response).to have_http_status(:success)
    end
  end

end
