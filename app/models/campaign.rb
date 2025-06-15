class Campaign < ApplicationRecord
  include AccountScoped
  include Auditable
  include Trackable
  include Searchable

  # Associations
  belongs_to :account
  belongs_to :user
  belongs_to :template, optional: true
  has_many :campaign_contacts, dependent: :destroy
  has_many :contacts, through: :campaign_contacts
  has_many :campaign_tags, dependent: :destroy
  has_many :tags, through: :campaign_tags

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subject, presence: true, length: { maximum: 255 }
  validates :status, inclusion: { in: %w[draft scheduled sending sent paused cancelled] }
  validates :send_type, inclusion: { in: %w[now scheduled] }
  validates :media_type, inclusion: { in: %w[text image video audio mixed] }
  validates :design_theme, inclusion: { in: %w[modern classic elegant minimal bold] }
  validates :font_family, inclusion: { in: %w[Inter Roboto Poppins Montserrat Lato Open-Sans] }
  validates :open_rate, :click_rate, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }, allow_nil: true
  validates :from_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :reply_to, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validates :header_image_url, :logo_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true
  validates :call_to_action_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_blank: true

  # Callbacks
  before_save :calculate_rates, if: :sent?

  # Scopes
  scope :draft, -> { where(status: "draft") }
  scope :scheduled, -> { where(status: "scheduled") }
  scope :sent, -> { where(status: "sent") }
  scope :active, -> { where(status: [ "draft", "scheduled", "sending" ]) }
  scope :completed, -> { where(status: "sent") }
  scope :ready_to_send, -> { where(status: "scheduled", scheduled_at: ..Time.current) }
  scope :recent, -> { order(created_at: :desc) }

  # Methods
  def draft?
    status == "draft"
  end

  def scheduled?
    status == "scheduled"
  end

  def sending?
    status == "sending"
  end

  def sent?
    status == "sent"
  end

  def paused?
    status == "paused"
  end

  def cancelled?
    status == "cancelled"
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
    update!(status: "scheduled", scheduled_at: datetime)
  end

  def send_now!
    update!(status: "sending")
    # Here you would enqueue a job to actually send the emails
    # SendCampaignJob.perform_later(self)
  end

  def mark_as_sent!
    update!(status: "sent", sent_at: Time.current)
  end

  def pause!
    update!(status: "paused") if sending?
  end

  def cancel!
    update!(status: "cancelled") unless sent?
  end

  def can_be_sent?
    draft? || scheduled?
  end

  # Media and Social Platform Methods
  def media_urls_array
    return [] if media_urls.blank?
    JSON.parse(media_urls)
  rescue JSON::ParserError
    []
  end

  def media_urls_array=(urls)
    self.media_urls = urls.to_json
  end

  def social_platforms_array
    return [] if social_platforms.blank?
    JSON.parse(social_platforms)
  rescue JSON::ParserError
    []
  end

  def social_platforms_array=(platforms)
    self.social_platforms = platforms.to_json
  end

  def has_media?
    media_type != "text" && media_urls_array.any?
  end

  def primary_media_url
    media_urls_array.first
  end

  def supports_platform?(platform)
    social_platforms_array.include?(platform.to_s)
  end

  private

  def calculate_rates
    # This would be implemented based on actual tracking data
    # For now, we'll keep the existing values
  end

  # Searchable fields for the concern
  def self.searchable_fields
    %w[name subject]
  end

  # Trackable engagement calculation
  def calculate_engagement_score
    score = 0
    
    # Base score for campaign status
    score += case status
             when 'sent' then 40
             when 'sending' then 20
             when 'scheduled' then 10
             else 0
             end
    
    # Performance-based scoring
    if sent? && open_rate.present?
      score += [open_rate * 0.4, 30].min
    end
    
    if sent? && click_rate.present?
      score += [click_rate * 2, 20].min
    end
    
    # Recency bonus
    if sent_at.present? && sent_at >= 30.days.ago
      score += 10
    end
    
    [score, 100].min
  end
end
