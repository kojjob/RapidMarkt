require 'rails_helper'

RSpec.describe CampaignsController, type: :controller do
  routes { Rails.application.routes }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  before do
    sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_account, account)
  end

  describe 'POST #create' do
    context 'with valid parameters' do
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

      it 'creates a new campaign' do
        expect {
          post :create, params: valid_params
        }.to change(Campaign, :count).by(1)
      end

      it 'assigns the campaign to the current account' do
        post :create, params: valid_params
        campaign = Campaign.last
        expect(campaign.account).to eq(account)
      end

      it 'assigns the campaign to the current user' do
        post :create, params: valid_params
        campaign = Campaign.last
        expect(campaign.user).to eq(user)
      end

      it 'sets the preview_text correctly' do
        post :create, params: valid_params
        campaign = Campaign.last
        expect(campaign.preview_text).to eq('This is a preview text')
      end

      it 'redirects to the campaign show page' do
        post :create, params: valid_params
        campaign = Campaign.last
        expect(response).to redirect_to(campaign)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          campaign: {
            name: '', # Invalid: name is required
            subject: 'Test Subject'
          }
        }
      end

      it 'does not create a new campaign' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Campaign, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end

    context 'with unpermitted parameters' do
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

      it 'ignores unpermitted parameters and uses controller logic' do
        post :create, params: params_with_unpermitted
        campaign = Campaign.last
        expect(campaign.account).to eq(account) # Should use @current_account
        expect(campaign.user).to eq(user)       # Should use current_user
        expect(campaign.account_id).not_to eq(999)
        expect(campaign.user_id).not_to eq(999)
      end
    end
  end

  describe 'GET #new' do
    it 'assigns a new campaign' do
      get :new
      expect(assigns(:campaign)).to be_a_new(Campaign)
    end

    it 'assigns the campaign to the current account' do
      get :new
      campaign = assigns(:campaign)
      expect(campaign.account).to eq(account)
    end
  end
end
