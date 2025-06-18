require 'rails_helper'

RSpec.describe TagsController, type: :controller do
  routes { Rails.application.routes }

  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:tag) { create(:tag, account: account) }

  before do
    sign_in user
    allow(controller).to receive(:current_user).and_return(user)
    allow(controller).to receive(:authenticate_user!).and_return(true)
    controller.instance_variable_set(:@current_account, account)
  end

  describe 'GET #index' do
    before do
      # Create some tags with contacts to test the contacts_count functionality
      3.times { create(:tag, account: account) }
    end

    it 'assigns @tags with contacts_count' do
      get :index
      expect(assigns(:tags)).to be_present
      expect(assigns(:tags).first).to respond_to(:contacts_count)
    end

    it 'assigns @total_tags_count' do
      get :index
      expect(assigns(:total_tags_count)).to eq(account.tags.count)
    end

    it 'renders the index template' do
      get :index
      expect(response).to render_template(:index)
    end

    it 'orders tags by name' do
      tag_a = create(:tag, account: account, name: 'alpha')
      tag_z = create(:tag, account: account, name: 'zulu')

      get :index
      tags = assigns(:tags).to_a
      expect(tags.map(&:name)).to eq([ 'alpha', 'zulu' ])
    end

    it 'does not cause SQL syntax errors with COUNT queries' do
      expect { get :index }.not_to raise_error
    end
  end

  describe 'GET #show' do
    it 'assigns the correct tag' do
      get :show, params: { id: tag.id }
      expect(assigns(:tag)).to eq(tag)
    end

    it 'assigns contacts for the tag' do
      contact = create(:contact, account: account)
      tag.contacts << contact

      get :show, params: { id: tag.id }
      expect(assigns(:contacts)).to include(contact)
    end
  end

  describe 'POST #create' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          tag: {
            name: 'Test Tag',
            description: 'Test Description',
            color: '#3B82F6'
          }
        }
      end

      it 'creates a new tag' do
        expect {
          post :create, params: valid_params
        }.to change(Tag, :count).by(1)
      end

      it 'assigns the tag to the current account' do
        post :create, params: valid_params
        tag = Tag.last
        expect(tag.account).to eq(account)
      end

      it 'redirects to tags index' do
        post :create, params: valid_params
        expect(response).to redirect_to(tags_path)
      end
    end

    context 'with invalid parameters' do
      let(:invalid_params) do
        {
          tag: {
            name: '', # Invalid: name is required
            description: 'Test Description'
          }
        }
      end

      it 'does not create a new tag' do
        expect {
          post :create, params: invalid_params
        }.not_to change(Tag, :count)
      end

      it 'renders the new template' do
        post :create, params: invalid_params
        expect(response).to render_template(:new)
      end
    end
  end

  describe 'PATCH #update' do
    context 'with valid parameters' do
      let(:valid_params) do
        {
          id: tag.id,
          tag: {
            name: 'Updated Tag Name'
          }
        }
      end

      it 'updates the tag' do
        patch :update, params: valid_params
        tag.reload
        expect(tag.name).to eq('updated tag name') # normalized to lowercase
      end

      it 'redirects to the tag' do
        patch :update, params: valid_params
        expect(response).to redirect_to(tag)
      end
    end
  end

  describe 'DELETE #destroy' do
    it 'deletes the tag' do
      tag_to_delete = create(:tag, account: account)
      expect {
        delete :destroy, params: { id: tag_to_delete.id }
      }.to change(Tag, :count).by(-1)
    end

    it 'redirects to tags index' do
      delete :destroy, params: { id: tag.id }
      expect(response).to redirect_to(tags_url)
    end
  end
end
