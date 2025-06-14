require 'rails_helper'

RSpec.describe "EmailTrackings", type: :request do
  describe "GET /open" do
    it "returns http success" do
      get "/email_tracking/open"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /click" do
    it "returns http success" do
      get "/email_tracking/click"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /unsubscribe" do
    it "returns http success" do
      get "/email_tracking/unsubscribe"
      expect(response).to have_http_status(:success)
    end
  end

end
