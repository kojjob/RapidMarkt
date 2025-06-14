class AuditLog < ApplicationRecord
  belongs_to :user
  belongs_to :resource, polymorphic: true, optional: true
  
  # Validations
  validates :action, presence: true
  
  # Scopes
  scope :recent, -> { where('performed_at > ?', 1.week.ago) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_resource, ->(resource) { where(resource: resource) }
  scope :security_events, -> { where(action: SECURITY_ACTIONS) }
  
  # Constants for common audit actions
  SECURITY_ACTIONS = %w[
    user_login
    user_logout
    user_created
    user_updated
    user_suspended
    role_changed
    password_changed
    failed_login
    account_locked
    permission_denied
  ].freeze
  
  USER_ACTIONS = %w[
    campaign_created
    campaign_updated
    campaign_sent
    template_created
    contact_imported
    analytics_exported
  ].freeze
  
  ADMIN_ACTIONS = %w[
    user_invited
    user_role_changed
    account_settings_updated
    billing_updated
  ].freeze
  
  # Class methods
  def self.log_security_event(user, action, details = {})
    create!(
      user: user,
      action: action,
      details: details.merge(category: 'security'),
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      performed_at: Time.current
    )
  end
  
  def self.log_user_action(user, action, resource = nil, details = {})
    create!(
      user: user,
      action: action,
      resource: resource,
      details: details.merge(category: 'user_action'),
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      performed_at: Time.current
    )
  end
  
  def self.log_admin_action(user, action, resource = nil, details = {})
    create!(
      user: user,
      action: action,
      resource: resource,
      details: details.merge(category: 'admin_action'),
      ip_address: Current.ip_address,
      user_agent: Current.user_agent,
      performed_at: Time.current
    )
  end
  
  def self.recent_activity(limit = 50)
    includes(:user, :resource)
      .order(performed_at: :desc)
      .limit(limit)
  end
  
  def self.security_summary(days = 7)
    security_events
      .where('performed_at > ?', days.days.ago)
      .group(:action)
      .count
  end
  
  # Instance methods
  def security_event?
    SECURITY_ACTIONS.include?(action)
  end
  
  def user_action?
    USER_ACTIONS.include?(action)
  end
  
  def admin_action?
    ADMIN_ACTIONS.include?(action)
  end
  
  def category
    details['category'] || 'unknown'
  end
  
  def formatted_details
    return details if details.is_a?(String)
    
    formatted = details.except('category', 'ip_address', 'user_agent')
    return 'No additional details' if formatted.empty?
    
    formatted.map { |k, v| "#{k.humanize}: #{v}" }.join(', ')
  end
  
  def location
    return details['location'] if details['location'].present?
    return 'Unknown' unless ip_address.present?
    
    # This could be enhanced with a geocoding service
    "#{ip_address}"
  end
  
  def browser_info
    return 'Unknown' unless user_agent.present?
    
    # Simple browser detection
    case user_agent
    when /Chrome/ then 'Chrome'
    when /Firefox/ then 'Firefox'
    when /Safari/ then 'Safari'
    when /Edge/ then 'Edge'
    else 'Unknown Browser'
    end
  end
  
  def risk_level
    case action
    when 'failed_login', 'account_locked', 'permission_denied'
      'high'
    when 'user_suspended', 'role_changed', 'password_changed'
      'medium'
    when 'user_login', 'user_logout'
      'low'
    else
      'info'
    end
  end
  
  def humanized_action
    action.humanize.titleize
  end
  
  def time_ago
    "#{time_ago_in_words(performed_at)} ago"
  end
  
  private
  
  def time_ago_in_words(time)
    ApplicationController.helpers.time_ago_in_words(time)
  rescue
    ((Time.current - time) / 1.hour).round(1).to_s + ' hours'
  end
end