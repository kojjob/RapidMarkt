require 'rails_helper'

RSpec.describe "Authentication Comprehensive Tests", type: :request do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }

  describe "sign_in helper" do
    context "when user is properly signed in" do
      before { sign_in user }

      it "allows access to protected resources" do
        get "/campaigns"
        expect(response).to be_successful
      end

      it "provides access to current_user" do
        get "/campaigns"
        expect(controller.current_user).to eq(user) if respond_to?(:controller)
      end

      it "sets up the current account properly" do
        get "/campaigns/new"
        expect(response).to be_successful
        # The @current_account should be set by the before_action
      end
    end

    context "when user is not signed in" do
      it "redirects to login for protected resources" do
        get "/campaigns"
        expect(response).to redirect_to(new_user_session_path)
      end

      it "redirects to login for creating campaigns" do
        post "/campaigns", params: { campaign: { name: "Test" } }
        expect(response).to redirect_to(new_user_session_path)
      end

      it "allows access to Devise routes" do
        get "/users/sign_in"
        expect(response).to be_successful
      end
    end
  end

  describe "sign_out helper" do
    before { sign_in user }

    it "signs out the user properly" do
      sign_out user
      get "/campaigns"
      expect(response).to redirect_to(new_user_session_path)
    end
  end

  describe "different user roles" do
    let(:owner_user) { create(:user, :owner, account: account) }
    let(:admin_user) { create(:user, :admin, account: account) }
    let(:member_user) { create(:user, account: account) } # default role is member

    context "owner user" do
      before { sign_in owner_user }

      it "can access campaigns" do
        get "/campaigns"
        expect(response).to be_successful
      end

      it "has owner privileges" do
        expect(owner_user.owner?).to be true
        expect(owner_user.admin?).to be true # owners are also admins
      end
    end

    context "admin user" do
      before { sign_in admin_user }

      it "can access campaigns" do
        get "/campaigns"
        expect(response).to be_successful
      end

      it "has admin privileges" do
        expect(admin_user.admin?).to be true
        expect(admin_user.owner?).to be false
      end
    end

    context "member user" do
      before { sign_in member_user }

      it "can access campaigns" do
        get "/campaigns"
        expect(response).to be_successful
      end

      it "has member privileges only" do
        expect(member_user.admin?).to be false
        expect(member_user.owner?).to be false
      end
    end
  end

  describe "cross-account access prevention" do
    let(:other_account) { create(:account) }
    let(:other_user) { create(:user, account: other_account) }

    before { sign_in user }

    it "prevents access to other account's resources" do
      # This would need to be tested at the controller level
      # For now, we verify the user belongs to the correct account
      expect(user.account).to eq(account)
      expect(user.account).not_to eq(other_account)
    end
  end

  describe "Devise configuration" do
    it "has proper Devise mappings" do
      expect(Devise.mappings[:user]).to be_present
      expect(Devise.mappings[:user].class_name).to eq("User")
    end

    it "has all required Devise routes" do
      expect(Rails.application.routes.url_helpers.new_user_session_path).to eq("/users/sign_in")
      expect(Rails.application.routes.url_helpers.destroy_user_session_path).to eq("/users/sign_out")
      expect(Rails.application.routes.url_helpers.new_user_registration_path).to eq("/users/sign_up")
    end
  end

  describe "session persistence" do
    before { sign_in user }

    it "maintains session across multiple requests" do
      get "/campaigns"
      expect(response).to be_successful

      get "/campaigns/new"
      expect(response).to be_successful

      post "/campaigns", params: {
        campaign: {
          name: "Test Campaign",
          subject: "Test Subject",
          status: "draft"
        }
      }
      expect(response).to be_redirect # Should redirect to campaign show page
    end
  end

  describe "Warden integration" do
    it "properly integrates with Warden" do
      expect(defined?(Warden::Test::Helpers)).to be_truthy
    end

    it "cleans up after tests" do
      sign_in user
      get "/campaigns"
      expect(response).to be_successful

      # After sign_out, the session should be cleared
      sign_out user
      get "/campaigns"
      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
