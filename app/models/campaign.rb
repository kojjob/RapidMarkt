class Campaign < ApplicationRecord
  # Associations
  belongs_to :account
  belongs_to :template, optional: true
  has_many :campaign_contacts, dependent: :destroy
  has_many :contacts, through: :campaign_contacts
  
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subject, presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: %w[draft scheduled sending sent paused cancelled] }
  validates :open_rate, :click_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  
  # Callbacks
  before_save :calculate_rates, if: :sent?
  
  # Scopes
  scope :draft, -> { where(status: 'draft') }
  scope :scheduled, -> { where(status: 'scheduled') }
  scope :sent, -> { where(status: 'sent') }
  scope :active, -> { where(status: ['draft', 'scheduled', 'sending']) }
  scope :completed, -> { where(status: 'sent') }
  scope :ready_to_send, -> { where(status: 'scheduled', scheduled_at: ..Time.current) }
  
  # Methods
  def draft?
    status == 'draft'
  end
  
  def scheduled?
    status == 'scheduled'
  end
  
  def sending?
    status == 'sending'
  end
  
  def sent?
    status == 'sent'
  end
  
  def paused?
    status == 'paused'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def ready_to_send?
    scheduled? && scheduled_at.present? && scheduled_at <= Time.current
  end
  
  def total_recipients
    contacts.count
  end
  
  def total_opens
    # This would be calculated from tracking data
    # For now, we'll use a placeholder calculation
    return 0 unless sent? && open_rate.present?
    
    (total_recipients * (open_rate / 100.0)).round
  end
  
  def total_clicks
    # This would be calculated from tracking data
    # For now, we'll use a placeholder calculation
    return 0 unless sent? && click_rate.present?
    
    (total_recipients * (click_rate / 100.0)).round
  end
  
  def schedule!(datetime)
    update!(status: 'scheduled', scheduled_at: datetime)
  end
  
  def send_now!
    update!(status: 'sending')
    # Here you would enqueue a job to actually send the emails
    # SendCampaignJob.perform_later(self)
  end
  
  def mark_as_sent!
    update!(status: 'sent', sent_at: Time.current)
  end
  
  def pause!
    update!(status: 'paused') if sending?
  end
  
  def cancel!
    update!(status: 'cancelled') unless sent?
  end
  
  private
  
  def calculate_rates
    # This would be implemented based on actual tracking data
    # For now, we'll keep the existing values
  end
end
