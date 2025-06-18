require 'rails_helper'

RSpec.describe "BrandVoices", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:brand_voice) { create(:brand_voice, account: account) }

  before do
    sign_in user
  end

  describe "GET /index" do
    it "returns http success" do
      get "/brand_voices"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get "/brand_voices/#{brand_voice.id}"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get "/brand_voices/new"
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it "returns http success" do
      post "/brand_voices", params: { brand_voice: { name: 'Test Voice', tone: 'professional', description: 'Test description' } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get "/brand_voices/#{brand_voice.id}/edit"
      expect(response).to have_http_status(:success)
    end
  end

  describe "PATCH /update" do
    it "returns http success" do
      patch "/brand_voices/#{brand_voice.id}", params: { brand_voice: { name: 'Updated Voice' } }
      expect(response).to have_http_status(:redirect)
    end
  end

  describe "DELETE /destroy" do
    it "returns http success" do
      delete "/brand_voices/#{brand_voice.id}"
      expect(response).to have_http_status(:redirect)
    end
  end
end
