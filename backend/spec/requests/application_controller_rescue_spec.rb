
require "rails_helper"

RSpec.describe "ApplicationController error mapping", type: :request do
  before(:all) do
    Rails.application.routes.disable_clear_and_finalize = true

    Rails.application.routes.draw do
      get "/__test__/not_found",  to: "test_errors#not_found"
      get "/__test__/bad_request", to: "test_errors#bad_request"
      get "/__test__/bulk_invalid", to: "test_errors#bulk_invalid"
      get "/__test__/boom", to: "test_errors#boom"
    end

    class TestErrorsController < ApplicationController
      def not_found
        raise ActiveRecord::RecordNotFound
      end

      def bad_request
        raise ApplicationErrors::BadRequest, "bad"
      end

      def bulk_invalid
        raise Notes::BulkCreate::BulkInvalid.new(
          errors: [{ index: 0, messages: ["x"] }]
        )
      end

      def boom
        raise "unexpected"
      end
    end
  end

  after(:all) do
    Rails.application.reload_routes!
    Object.send(:remove_const, :TestErrorsController) if defined?(TestErrorsController)
  end

  def json
    JSON.parse(response.body)
  end

  it "maps RecordNotFound to 404" do
    get "/__test__/not_found"
    expect(response).to have_http_status(:not_found)
    expect(json["errors"]).to be_an(Array)
  end

  it "maps BadRequest to 400" do
    get "/__test__/bad_request"
    expect(response).to have_http_status(:bad_request)
    expect(json["errors"]).to be_an(Array)
  end

  it "maps BulkInvalid to 422 with bulk format" do
    get "/__test__/bulk_invalid"
    expect(response).to have_http_status(:unprocessable_entity)
    expect(json["errors"]).to be_an(Array)
    expect(json["errors"].first).to have_key("index")
    expect(json["errors"].first).to have_key("messages")
  end

  it "raises unexpected errors in test env" do
    expect { get "/__test__/boom" }.to raise_error(RuntimeError, "unexpected")
  end
end