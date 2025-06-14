class Contact < ApplicationRecord
  # Associations
  belongs_to :account
  has_many :campaign_contacts, dependent: :destroy
  has_many :campaigns, through: :campaign_contacts
  has_many :contact_tags, dependent: :destroy
  has_many :tags, through: :contact_tags

  # Validations
  validates :email, presence: true, uniqueness: { scope: :account_id, case_sensitive: false },
                   format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :first_name, :last_name, length: { maximum: 50 }
  validates :status, inclusion: { in: %w[subscribed unsubscribed bounced complained] }

  # Callbacks
  before_validation :normalize_email
  before_validation :set_default_status, if: -> { status.blank? }
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

  private

  def set_default_status
    self.status = "subscribed"
  end

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
end
