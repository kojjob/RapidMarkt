class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_account
  before_action :set_notifications, if: :user_signed_in?
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def set_current_account
    return unless user_signed_in?

    @current_account = current_user.account
    Current.account = @current_account
  end

  def set_notifications
    # Sample notification data - in production this would come from a Notification model
    @recent_notifications = [
      {
        type: 'campaign_sent',
        title: 'Campaign "Welcome Series" sent successfully',
        message: 'Your campaign was delivered to 245 contacts',
        created_at: 2.hours.ago,
        read: false
      },
      {
        type: 'new_contact',
        title: 'New contact subscribed',
        message: 'john.doe@example.com joined your mailing list',
        created_at: 4.hours.ago,
        read: false
      },
      {
        type: 'campaign_completed',
        title: 'Campaign analytics ready',
        message: 'View detailed performance metrics for your latest campaign',
        created_at: 1.day.ago,
        read: true
      }
    ]

    @unread_notifications_count = @recent_notifications.count { |n| !n[:read] }
  end

  def require_account_owner
    redirect_to root_path unless current_user&.owner?
  end

  def require_account_admin
    redirect_to root_path unless current_user&.admin? || current_user&.owner?
  end

  private

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :first_name, :last_name ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :first_name, :last_name ])
  end
end
