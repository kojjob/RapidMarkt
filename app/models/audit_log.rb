class AuditLog < ApplicationRecord
  include AccountScoped

  # Associations
  belongs_to :user, optional: true
  belongs_to :resource, polymorphic: true, optional: true

  # Validations
  validates :action, presence: true
  validates :details, presence: true
  validates :performed_at, presence: true

  # Scopes
  scope :recent, -> { order(performed_at: :desc) }
  scope :by_action, ->(action) { where(action: action) }
  scope :by_user, ->(user) { where(user: user) }
  scope :by_resource, ->(resource) { where(resource: resource) }
  scope :within_timeframe, ->(start_time, end_time) { where(performed_at: start_time..end_time) }
  scope :today, -> { where(performed_at: Date.current.beginning_of_day..Date.current.end_of_day) }
  scope :this_week, -> { where(performed_at: 1.week.ago..Time.current) }
  scope :this_month, -> { where(performed_at: 1.month.ago..Time.current) }

  # Class methods
  def self.log_action(user:, action:, details:, resource: nil, ip_address: nil, user_agent: nil)
    create!(
      user: user,
      action: action,
      details: details,
      resource: resource,
      ip_address: ip_address,
      user_agent: user_agent,
      performed_at: Time.current
    )
  end

  def self.cleanup_old_logs(older_than: 6.months)
    where("performed_at < ?", older_than.ago).delete_all
  end

  # Instance methods
  def user_name
    user&.full_name || "System"
  end

  def resource_name
    return "N/A" unless resource
    
    if resource.respond_to?(:name) && resource.name.present?
      resource.name
    elsif resource.respond_to?(:title) && resource.title.present?
      resource.title
    elsif resource.respond_to?(:email) && resource.email.present?
      resource.email
    else
      "#{resource.class.name} ##{resource.id}"
    end
  end

  def formatted_details
    case details
    when Hash
      details.map { |k, v| "#{k}: #{v}" }.join(', ')
    when String
      details
    else
      details.to_s
    end
  end
end