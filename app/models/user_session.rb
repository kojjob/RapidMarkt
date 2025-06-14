class UserSession < ApplicationRecord
  belongs_to :user
  
  # Validations
  validates :session_id, presence: true, uniqueness: true
  validates :last_activity_at, :expires_at, presence: true
  
  # Scopes
  scope :active, -> { where(active: true) }
  scope :expired, -> { where('expires_at < ?', Time.current) }
  scope :recent, -> { where('last_activity_at > ?', 15.minutes.ago) }
  
  # Callbacks
  before_create :set_expires_at
  before_save :deactivate_if_expired
  
  # Class methods
  def self.cleanup_expired
    where('expires_at < ?', Time.current).update_all(active: false)
  end
  
  def self.active_users_count
    joins(:user).where(active: true, users: { status: 'active' }).distinct.count(:user_id)
  end
  
  # Instance methods
  def expired?
    expires_at < Time.current
  end
  
  def recent?
    last_activity_at > 15.minutes.ago
  end
  
  def touch_activity!
    update!(last_activity_at: Time.current)
  end
  
  def deactivate!
    update!(active: false)
  end
  
  def extend_session!(duration = 24.hours)
    update!(expires_at: Time.current + duration)
  end
  
  def location
    return 'Unknown' unless ip_address.present?
    
    # This could be enhanced with a geocoding service
    "#{ip_address} (Location lookup not implemented)"
  end
  
  def browser_info
    return 'Unknown' unless user_agent.present?
    
    # Simple browser detection - could be enhanced with a proper user agent parser
    case user_agent
    when /Chrome/
      'Chrome'
    when /Firefox/
      'Firefox'
    when /Safari/
      'Safari'
    when /Edge/
      'Edge'
    else
      'Unknown Browser'
    end
  end
  
  def device_type
    return 'Unknown' unless user_agent.present?
    
    case user_agent
    when /Mobile/
      'Mobile'
    when /Tablet/
      'Tablet'
    else
      'Desktop'
    end
  end
  
  private
  
  def set_expires_at
    self.expires_at ||= 24.hours.from_now
  end
  
  def deactivate_if_expired
    self.active = false if expired?
  end
end