class Contact < ApplicationRecord
  include AccountScoped
  include Auditable
  include Trackable
  include Searchable

  # Associations
  belongs_to :account
  has_many :campaign_contacts, dependent: :destroy
  has_many :campaigns, through: :campaign_contacts
  has_many :contact_tags, dependent: :destroy
  has_many :tags, through: :contact_tags
  has_many :contact_lifecycle_logs, -> { order(created_at: :desc) }, dependent: :destroy
  has_many :automation_enrollments, dependent: :destroy
  has_many :email_automations, through: :automation_enrollments

  # Validations
  validates :email, presence: true, uniqueness: { scope: :account_id, case_sensitive: false },
                   format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, length: { maximum: 50 }
  validates :status, inclusion: { in: %w[subscribed unsubscribed bounced complained] }

  # Callbacks
  before_validation :normalize_email
  before_save :set_subscribed_at, if: :will_save_change_to_status?

  # Scopes
  scope :subscribed, -> { where(status: "subscribed") }
  scope :unsubscribed, -> { where(status: "unsubscribed") }
  scope :bounced, -> { where(status: "bounced") }
  scope :complained, -> { where(status: "complained") }
  scope :active, -> { where(status: "subscribed") }
  scope :with_tag, ->(tag_name) { joins(:tags).where(tags: { name: tag_name }) }
  scope :search, ->(query) {
    where("email ILIKE ? OR first_name ILIKE ? OR last_name ILIKE ?",
          "%#{query}%", "%#{query}%", "%#{query}%")
  }

  # Methods
  def subscribed?
    status == "subscribed"
  end

  def unsubscribed?
    status == "unsubscribed"
  end

  def bounced?
    status == "bounced"
  end

  def complained?
    status == "complained"
  end

  def active?
    subscribed?
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email
  end

  def subscribe!
    update!(status: "subscribed", subscribed_at: Time.current, unsubscribed_at: nil)
  end

  def unsubscribe!
    update!(status: "unsubscribed", unsubscribed_at: Time.current)
  end

  def mark_as_bounced!
    update!(status: "bounced")
  end

  def mark_as_complained!
    update!(status: "complained")
  end

  def tag_names
    tags.pluck(:name)
  end

  def add_tag(tag_or_name)
    if tag_or_name.is_a?(Tag)
      tags << tag_or_name unless tags.include?(tag_or_name)
    else
      tag = account.tags.find_or_create_by(name: tag_or_name.to_s.strip.downcase)
      tags << tag unless tags.include?(tag)
    end
  end

  def remove_tag(tag_or_name)
    if tag_or_name.is_a?(Tag)
      tags.delete(tag_or_name)
    else
      tag = account.tags.find_by(name: tag_or_name.to_s.strip.downcase)
      tags.delete(tag) if tag
    end
  end

  def has_tag?(tag_or_name)
    if tag_or_name.is_a?(Tag)
      tags.include?(tag_or_name)
    else
      tags.exists?(name: tag_or_name.to_s.strip.downcase)
    end
  end

  # Check if contact can receive emails
  def can_receive_emails?
    subscribed? && !bounced?
  end

  # Get engagement level as human-readable string
  def engagement_level_text
    case engagement_level
    when 'highly_engaged'
      'Highly Engaged'
    when 'moderately_engaged'
      'Moderately Engaged'
    when 'somewhat_engaged'
      'Somewhat Engaged'
    when 'barely_engaged'
      'Barely Engaged'
    when 'not_engaged'
      'Not Engaged'
    else
      'Unknown'
    end
  end

  # Calculate contact's value score
  def value_score
    score = 0
    
    # Engagement score contributes 40%
    score += (engagement_score || 0) * 0.4
    
    # Activity recency contributes 30%
    if last_opened_at.present?
      days_ago = (Date.current - last_opened_at.to_date).to_i
      recency_score = case days_ago
                      when 0..7 then 100
                      when 8..30 then 70
                      when 31..90 then 40
                      else 10
                      end
      score += recency_score * 0.3
    end
    
    # Profile completeness contributes 20%
    completeness = profile_completeness_percentage
    score += completeness * 0.2
    
    # Lifecycle stage contributes 10%
    lifecycle_score = case lifecycle_stage
                      when 'customer' then 100
                      when 'advocate' then 90
                      when 'prospect' then 60
                      when 'lead' then 30
                      else 10
                      end
    score += lifecycle_score * 0.1
    
    score.round(2)
  end

  # Calculate profile completeness percentage
  def profile_completeness_percentage
    total_fields = 6
    completed_fields = 0
    
    completed_fields += 1 if first_name.present?
    completed_fields += 1 if last_name.present?
    completed_fields += 1 if email.present? # Always present due to validation
    completed_fields += 1 if company.present?
    completed_fields += 1 if job_title.present?
    completed_fields += 1 if location.present?
    
    (completed_fields.to_f / total_fields * 100).round(2)
  end

  # Generate unsubscribe token
  def generate_unsubscribe_token!
    self.unsubscribe_token = SecureRandom.urlsafe_base64(32)
    save!(validate: false) # Skip validations to avoid issues with unsubscribe flow
  end

  def unsubscribe_token
    super || tap { generate_unsubscribe_token! }.unsubscribe_token
  end

  private

  def normalize_email
    self.email = email&.downcase&.strip
  end

  def set_subscribed_at
    if status == "subscribed" && status_was != "subscribed"
      self.subscribed_at = Time.current
      self.unsubscribed_at = nil
    elsif status == "unsubscribed" && status_was != "unsubscribed"
      self.unsubscribed_at = Time.current
    end
  end

  # Searchable fields for the concern
  def self.searchable_fields
    %w[first_name last_name email company job_title]
  end

  # Trackable engagement calculation (override from concern)
  def calculate_engagement_score
    score = 0
    
    # Base score for subscription status
    score += case status
             when 'subscribed' then 20
             when 'unsubscribed' then 0
             when 'bounced' then 0
             else 10
             end
    
    # Recent email activity
    if last_opened_at.present?
      days_since_open = (Date.current - last_opened_at.to_date).to_i
      score += case days_since_open
               when 0..7 then 30
               when 8..30 then 20
               when 31..90 then 10
               else 0
               end
    end
    
    # Click activity
    if last_clicked_at.present?
      days_since_click = (Date.current - last_clicked_at.to_date).to_i
      score += case days_since_click
               when 0..7 then 25
               when 8..30 then 15
               when 31..90 then 5
               else 0
               end
    end
    
    # Profile completeness
    score += profile_completeness_percentage * 0.2
    
    # Lifecycle stage bonus
    score += case lifecycle_stage
             when 'customer' then 20
             when 'advocate' then 15
             when 'prospect' then 10
             when 'lead' then 5
             else 0
             end
    
    [score, 100].min
  end
end
