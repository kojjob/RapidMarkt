class Template < ApplicationRecord
  include AccountScoped
  include Auditable
  include Trackable
  include Searchable

  # Associations
  belongs_to :account
  belongs_to :brand_voice, optional: true
  has_many :campaigns, dependent: :nullify

  # Enums
  enum :template_type, {
    email: "email",
    newsletter: "newsletter",
    promotional: "promotional",
    transactional: "transactional"
  }, prefix: :category

  # Alias for categories (used by controller)
  class << self
    alias_method :categories, :template_types
  end

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subject, presence: true, length: { maximum: 255 }
  validates :body, presence: true
  validates :status, inclusion: { in: %w[draft active archived] }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :draft, -> { where(status: "draft") }
  scope :archived, -> { where(status: "archived") }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :search, ->(query) {
    where("name ILIKE ? OR subject ILIKE ?", "%#{query}%", "%#{query}%")
  }

  # Methods
  def active?
    status == "active"
  end

  def draft?
    status == "draft"
  end

  def archived?
    status == "archived"
  end

  def activate!
    update!(status: "active")
  end

  def archive!
    update!(status: "archived")
  end

  def duplicate
    dup.tap do |template|
      template.name = "#{name} (Copy)"
      template.status = "draft"
    end
  end

  def render_for_contact(contact)
    rendered_subject = interpolate_variables(subject, contact)
    rendered_body = interpolate_variables(body, contact)

    {
      subject: rendered_subject,
      body: rendered_body
    }
  end

  def preview_variables
    {
      "contact.first_name" => "John",
      "contact.last_name" => "Doe",
      "contact.email" => "john.doe@example.com",
      "contact.full_name" => "John Doe",
      "account.name" => account.name,
      "unsubscribe_url" => "[UNSUBSCRIBE_URL]",
      "current_date" => Date.current.strftime("%B %d, %Y")
    }
  end

  def preview
    rendered_subject = interpolate_preview_variables(subject)
    rendered_body = interpolate_preview_variables(body)

    {
      subject: rendered_subject,
      body: rendered_body
    }
  end

  def variable_placeholders
    variables = []

    [ subject, body ].each do |content|
      next if content.blank?

      variables += content.scan(/\{\{\s*([^}]+)\s*\}\}/).flatten
    end

    variables.uniq.sort
  end

  private

  def interpolate_variables(content, contact)
    return content if content.blank?

    variables = {
      "contact.first_name" => contact.first_name,
      "contact.last_name" => contact.last_name,
      "contact.email" => contact.email,
      "contact.full_name" => contact.full_name,
      "account.name" => account.name,
      "unsubscribe_url" => generate_unsubscribe_url(contact),
      "current_date" => Date.current.strftime("%B %d, %Y")
    }

    content.gsub(/\{\{\s*([^}]+)\s*\}\}/) do |match|
      variable_name = $1.strip
      variables[variable_name] || match
    end
  end

  def interpolate_preview_variables(content)
    return content if content.blank?

    content.gsub(/\{\{\s*([^}]+)\s*\}\}/) do |match|
      variable_name = $1.strip
      preview_variables[variable_name] || match
    end
  end

  def generate_unsubscribe_url(contact)
    # This would generate a proper unsubscribe URL
    # For now, return a placeholder
    "[UNSUBSCRIBE_URL_FOR_#{contact.id}]"
  end

  def apply_brand_voice(content = nil)
    return content || self.content unless brand_voice

    target_content = content || self.content
    BrandVoiceService.new(brand_voice).apply_voice(target_content)
  end

  def content_with_brand_voice
    apply_brand_voice
  end

  def brand_voice_compatibility_score
    return nil unless brand_voice

    BrandVoiceService.new(brand_voice).analyze_content_compatibility(content)
  end

  # Searchable fields for the concern
  def self.searchable_fields
    %w[name subject body]
  end

  # Trackable engagement calculation
  def calculate_engagement_score
    score = 0

    # Base score for template status
    score += case status
    when "active" then 30
    when "draft" then 10
    else 0
    end

    # Usage-based scoring
    campaign_count = campaigns.count
    score += [ campaign_count * 5, 40 ].min

    # Performance-based scoring from campaigns
    if campaigns.sent.any?
      avg_open_rate = campaigns.sent.average(:open_rate) || 0
      avg_click_rate = campaigns.sent.average(:click_rate) || 0

      score += [ avg_open_rate * 0.2, 20 ].min
      score += [ avg_click_rate * 1.5, 10 ].min
    end

    [ score, 100 ].min
  end
end
