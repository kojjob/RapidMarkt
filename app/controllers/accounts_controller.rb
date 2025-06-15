class AccountsController < ApplicationController
  before_action :require_account_owner, except: [ :show ]
  before_action :set_account, only: [ :show, :edit, :update ]

  def show
    @subscription = @current_account.subscription
    @usage_stats = calculate_usage_stats
    @team_members = @current_account.users.order(:created_at)
  end

  def edit
  end

  def update
    if @current_account.update(account_params)
      redirect_to account_path, notice: "Account was successfully updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def billing
    @subscription = @current_account.subscription
    @invoices = @subscription&.invoices&.order(created_at: :desc)&.limit(10) || []
    @usage_stats = calculate_usage_stats
  end

  def team
    @team_members = @current_account.users.order(:created_at)
    @pending_invitations = @current_account.user_invitations.pending.order(:created_at)
  end

  def invite_user
    @invitation = @current_account.user_invitations.build(invitation_params)
    @invitation.invited_by = current_user

    if @invitation.save
      UserInvitationMailer.invite(@invitation).deliver_later
      redirect_to team_account_path, notice: "Invitation sent successfully."
    else
      @team_members = @current_account.users.order(:created_at)
      @pending_invitations = @current_account.user_invitations.pending.order(:created_at)
      render :team, status: :unprocessable_entity
    end
  end

  def remove_user
    user = @current_account.users.find(params[:user_id])

    if user == current_user
      redirect_to team_account_path, alert: "You cannot remove yourself from the account."
    elsif user.owner?
      redirect_to team_account_path, alert: "Cannot remove the account owner."
    else
      user.user_roles.where(account: @current_account).destroy_all
      redirect_to team_account_path, notice: "User removed from account."
    end
  end

  def cancel_invitation
    invitation = @current_account.user_invitations.pending.find(params[:invitation_id])
    invitation.update(status: "cancelled")
    redirect_to team_account_path, notice: "Invitation cancelled."
  end

  def settings
    @notification_preferences = current_user.notification_preferences || {}
  end

  def update_settings
    if current_user.update(settings_params)
      redirect_to account_settings_path, notice: "Settings updated successfully."
    else
      @notification_preferences = current_user.notification_preferences || {}
      render :settings, status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = @current_account
  end

  def account_params
    params.require(:account).permit(:name, :company_name, :website, :phone, :address, :city, :state, :zip_code, :country)
  end

  def invitation_params
    params.require(:user_invitation).permit(:email, :role)
  end

  def settings_params
    params.require(:user).permit(
      notification_preferences: [
        :email_campaign_sent,
        :email_campaign_completed,
        :new_subscriber,
        :weekly_report,
        :monthly_report
      ]
    )
  end

  def calculate_usage_stats
    current_month = Date.current.beginning_of_month..Date.current.end_of_month

    {
      campaigns_this_month: @current_account.campaigns.where(created_at: current_month).count,
      emails_sent_this_month: CampaignContact.joins(:campaign)
                                            .where(campaigns: { account: @current_account })
                                            .where(sent_at: current_month)
                                            .count,
      contacts_count: @current_account.contacts.count,
      templates_count: @current_account.templates.count,
      storage_used: calculate_storage_usage
    }
  end

  def calculate_storage_usage
    # Calculate storage usage for templates, uploaded images, etc.
    # This is a placeholder - implement based on your storage strategy
    0
  end
end
