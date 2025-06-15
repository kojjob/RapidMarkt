require 'rails_helper'

RSpec.describe "Campaigns", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before do
    sign_in user
  end

  describe "POST /campaigns" do
    context "with valid parameters" do
      let(:valid_params) do
        {
          campaign: {
            name: 'Test Campaign',
            subject: 'Test Subject',
            preview_text: 'This is a preview text',
            status: 'draft',
            content: 'Campaign content',
            from_name: 'Test Sender',
            from_email: 'test@example.com'
          }
        }
      end

      it "creates a new campaign" do
        expect {
          post "/campaigns", params: valid_params
        }.to change(Campaign, :count).by(1)
      end

      it "assigns the campaign to the current account" do
        post "/campaigns", params: valid_params
        campaign = Campaign.last
        expect(campaign.account).to eq(account)
      end

      it "assigns the campaign to the current user" do
        post "/campaigns", params: valid_params
        campaign = Campaign.last
        expect(campaign.user).to eq(user)
      end

      it "sets the preview_text correctly" do
        post "/campaigns", params: valid_params
        campaign = Campaign.last
        expect(campaign.preview_text).to eq('This is a preview text')
      end

      it "redirects to the campaign show page" do
        post "/campaigns", params: valid_params
        campaign = Campaign.last
        expect(response).to redirect_to(campaign_path(campaign))
      end
    end

    context "with invalid parameters" do
      let(:invalid_params) do
        {
          campaign: {
            name: '', # Invalid: name is required
            subject: 'Test Subject'
          }
        }
      end

      it "does not create a new campaign" do
        expect {
          post "/campaigns", params: invalid_params
        }.not_to change(Campaign, :count)
      end

      it "returns unprocessable entity status" do
        post "/campaigns", params: invalid_params
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "with unpermitted parameters" do
      let(:params_with_unpermitted) do
        {
          campaign: {
            name: 'Test Campaign',
            subject: 'Test Subject',
            status: 'draft', # Required field
            account_id: 999, # This should be ignored
            user_id: 999     # This should be ignored
          }
        }
      end

      it "ignores unpermitted parameters and uses controller logic" do
        expect {
          post "/campaigns", params: params_with_unpermitted
        }.to change(Campaign, :count).by(1)

        campaign = Campaign.last
        expect(campaign.account).to eq(account) # Should use @current_account
        expect(campaign.user).to eq(user)       # Should use current_user
        expect(campaign.account_id).not_to eq(999)
        expect(campaign.user_id).not_to eq(999)
      end
    end
  end

  describe "GET /campaigns/new" do
    it "returns a successful response" do
      get "/campaigns/new"
      expect(response).to be_successful
    end

    it "assigns a new campaign" do
      get "/campaigns/new"
      expect(assigns(:campaign)).to be_a_new(Campaign)
    end

    it "assigns the campaign to the current account" do
      get "/campaigns/new"
      campaign = assigns(:campaign)
      expect(campaign.account).to eq(account)
    end
  end

  describe "authentication" do
    context "when user is not signed in" do
      before { sign_out user }

      it "redirects to sign in page for GET /campaigns/new" do
        get "/campaigns/new"
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects to sign in page for POST /campaigns" do
        post "/campaigns", params: { campaign: { name: "Test" } }
        expect(response).to redirect_to(new_user_session_path)
      end
    end
  end
end
