class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :authenticate_user!
  before_action :set_current_account
  before_action :configure_permitted_parameters, if: :devise_controller?

  protected

  def set_current_account
    return unless user_signed_in?

    @current_account = current_user.account
    Current.account = @current_account
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
