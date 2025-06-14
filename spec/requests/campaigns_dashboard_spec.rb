require 'rails_helper'

RSpec.describe "Campaigns Dashboard", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before do
    sign_in user
  end

  describe "GET /campaigns/dashboard" do
    context "with no campaigns" do
      it "returns a successful response" do
        get dashboard_campaigns_path
        expect(response).to be_successful
      end

      it "shows zero stats" do
        get dashboard_campaigns_path
        expect(response.body).to include("0") # Should show 0 for total campaigns
      end
    end

    context "with campaigns" do
      let!(:draft_campaign) { create(:campaign, account: account, user: user, status: 'draft') }
      let!(:sent_campaign) { create(:campaign, :sent, account: account, user: user, status: 'sent') }
      let!(:sending_campaign) { create(:campaign, account: account, user: user, status: 'sending') }

      it "returns a successful response" do
        get dashboard_campaigns_path
        expect(response).to be_successful
      end

      it "displays campaign statistics" do
        get dashboard_campaigns_path
        expect(assigns(:total_campaigns)).to eq(3)
        expect(assigns(:recent_campaigns)).to include(draft_campaign, sent_campaign, sending_campaign)
      end

      it "calculates active campaigns correctly" do
        get dashboard_campaigns_path
        # Active campaigns should include sending campaigns
        expect(assigns(:active_campaigns)).to be >= 1
      end
    end

    context "JSON format" do
      let!(:campaign) { create(:campaign, account: account, user: user) }

      it "returns JSON data" do
        get dashboard_campaigns_path, params: { format: :json }
        expect(response).to be_successful
        expect(response.content_type).to include('application/json')

        json_response = JSON.parse(response.body)
        expect(json_response).to have_key('total_campaigns')
        expect(json_response).to have_key('active_campaigns')
        expect(json_response).to have_key('performance_data')
        expect(json_response).to have_key('status_distribution')
      end
    end
  end

  describe "Campaign management actions" do
    let!(:campaign) { create(:campaign, account: account, user: user, status: 'sending') }

    describe "POST /campaigns/:id/pause" do
      it "pauses a sending campaign" do
        post pause_campaign_path(campaign), params: { format: :json }
        expect(response).to be_successful

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(campaign.reload.status).to eq('paused')
      end

      it "fails to pause a non-sending campaign" do
        campaign.update!(status: 'draft')
        post pause_campaign_path(campaign), params: { format: :json }

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be false
      end
    end

    describe "POST /campaigns/:id/resume" do
      let!(:paused_campaign) { create(:campaign, account: account, user: user, status: 'paused') }

      it "resumes a paused campaign" do
        post resume_campaign_path(paused_campaign), params: { format: :json }
        expect(response).to be_successful

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(paused_campaign.reload.status).to eq('sending')
      end
    end

    describe "POST /campaigns/:id/stop" do
      it "stops a sending campaign" do
        post stop_campaign_path(campaign), params: { format: :json }
        expect(response).to be_successful

        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true
        expect(campaign.reload.status).to eq('cancelled')
      end
    end

    describe "POST /campaigns/:id/duplicate" do
      it "duplicates a campaign" do
        expect {
          post duplicate_campaign_path(campaign), params: { format: :json }
        }.to change(Campaign, :count).by(1)

        expect(response).to be_successful
        json_response = JSON.parse(response.body)
        expect(json_response['success']).to be true

        new_campaign = Campaign.last
        expect(new_campaign.name).to include('(Copy)')
        expect(new_campaign.status).to eq('draft')
        expect(new_campaign.account).to eq(account)
        expect(new_campaign.user).to eq(user)
      end
    end
  end

  describe "Security" do
    let(:other_account) { create(:account) }
    let(:other_user) { create(:user, account: other_account) }
    let!(:other_campaign) { create(:campaign, account: other_account, user: other_user) }

    it "prevents access to other account's campaigns" do
      expect {
        post pause_campaign_path(other_campaign), params: { format: :json }
      }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "prevents dashboard access to other account's data" do
      get dashboard_campaigns_path
      expect(assigns(:recent_campaigns)).not_to include(other_campaign)
    end
  end
end
