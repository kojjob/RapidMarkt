class Template < ApplicationRecord
  # Associations
  belongs_to :account
  belongs_to :user
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
  scope :by_design_system, ->(system) { where(design_system: system) }
  scope :public_templates, -> { where(is_public: true) }
  scope :premium, -> { where(is_premium: true) }
  scope :free, -> { where(is_premium: false) }
  scope :popular, -> { order(usage_count: :desc) }
  scope :highest_rated, -> { order(rating: :desc) }
  scope :search, ->(query) {
    where("name ILIKE ? OR subject ILIKE ? OR description ILIKE ?", "%#{query}%", "%#{query}%", "%#{query}%")
  }
  scope :by_tags, ->(tag_list) {
    where("tags && ARRAY[?]::text[]", Array(tag_list))
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
      template.is_public = false
      template.usage_count = 0
      template.rating = 0.0
    end
  end

  def increment_usage!
    increment!(:usage_count)
  end

  def add_rating(score)
    # Simple rating system - in production you'd want more sophisticated rating
    current_total = rating * usage_count
    new_total = current_total + score
    new_usage = usage_count + 1
    update!(rating: (new_total / new_usage).round(2))
  end

  def free?
    !is_premium?
  end

  def premium?
    is_premium?
  end

  def public?
    is_public?
  end

  def has_tag?(tag_name)
    tags.include?(tag_name.to_s)
  end

  def add_tag(tag_name)
    return if has_tag?(tag_name)
    update!(tags: tags + [tag_name.to_s])
  end

  def remove_tag(tag_name)
    update!(tags: tags - [tag_name.to_s])
  end

  def render_for_contact(contact, campaign: nil)
    context = build_rendering_context(contact, campaign)
    
    rendered_subject = render_template_content(subject, context)
    rendered_body = render_template_content(body, context)
    rendered_body = apply_design_system(rendered_body, context)

    {
      subject: rendered_subject,
      body: rendered_body
    }
  end

  def render_preview(sample_data: {})
    context = build_preview_context(sample_data)
    
    rendered_subject = render_template_content(subject, context)
    rendered_body = render_template_content(body, context)
    rendered_body = apply_design_system(rendered_body, context)

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

  def build_rendering_context(contact, campaign = nil)
    base_context = {
      "contact.first_name" => contact.first_name,
      "contact.last_name" => contact.last_name,
      "contact.email" => contact.email,
      "contact.full_name" => contact.full_name,
      "account.name" => account.name,
      "unsubscribe_url" => generate_unsubscribe_url(contact),
      "current_date" => Date.current.strftime("%B %d, %Y"),
      "current_time" => Time.current.strftime("%I:%M %p"),
      "current_year" => Date.current.year.to_s
    }

    if campaign
      base_context.merge!(
        "campaign.name" => campaign.name,
        "campaign.from_name" => campaign.from_name
      )
    end

    # Merge custom variables
    base_context.merge(variables || {})
  end

  def build_preview_context(sample_data = {})
    default_context = {
      "contact.first_name" => "John",
      "contact.last_name" => "Doe", 
      "contact.email" => "john.doe@example.com",
      "contact.full_name" => "John Doe",
      "account.name" => account.name,
      "unsubscribe_url" => "[UNSUBSCRIBE_URL]",
      "current_date" => Date.current.strftime("%B %d, %Y"),
      "current_time" => Time.current.strftime("%I:%M %p"),
      "current_year" => Date.current.year.to_s,
      "campaign.name" => "Sample Campaign",
      "campaign.from_name" => account.name
    }

    default_context.merge(variables || {}).merge(sample_data)
  end

  def render_template_content(content, context)
    return content if content.blank?

    # Handle simple variable substitution
    rendered = content.gsub(/\{\{\s*([^}]+)\s*\}\}/) do |match|
      variable_name = $1.strip
      
      # Handle conditional logic: {{if variable}}content{{/if}}
      if variable_name.start_with?('if ')
        handle_conditional(match, context)
      else
        context[variable_name] || match
      end
    end

    # Handle loops: {{each contacts}}...{{/each}}
    rendered = handle_loops(rendered, context)
    
    rendered
  end

  def handle_conditional(match, context)
    # Simple conditional logic - can be enhanced
    match # For now, return the original match
  end

  def handle_loops(content, context)
    # Simple loop handling - can be enhanced
    content
  end

  def apply_design_system(content, context)
    return content unless design_system.present?

    case design_system
    when 'modern'
      apply_modern_design(content, context)
    when 'classic'
      apply_classic_design(content, context)
    when 'minimal'
      apply_minimal_design(content, context)
    else
      content
    end
  end

  def apply_modern_design(content, context)
    # Apply modern design wrapper with color scheme
    colors = color_scheme.with_indifferent_access
    primary_color = colors[:primary] || '#2563eb'
    secondary_color = colors[:secondary] || '#64748b'
    
    wrapped_content = %{
      <div style="font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif; max-width: 600px; margin: 0 auto; background: white;">
        <div style="background: linear-gradient(135deg, #{primary_color}, #{secondary_color}); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 28px; font-weight: 700;">#{account.name}</h1>
        </div>
        <div style="padding: 40px 30px;">
          #{content}
        </div>
        <div style="background: #f8fafc; padding: 30px; text-align: center; font-size: 14px; color: #64748b;">
          <p style="margin: 0;">© #{Date.current.year} #{account.name}. All rights reserved.</p>
        </div>
      </div>
    }
    
    wrapped_content
  end

  def apply_classic_design(content, context)
    # Apply classic email design
    %{
      <div style="font-family: Georgia, serif; max-width: 600px; margin: 0 auto; background: white; border: 1px solid #e5e7eb;">
        <div style="background: #1f2937; padding: 20px; text-align: center;">
          <h1 style="color: white; margin: 0; font-size: 24px;">#{account.name}</h1>
        </div>
        <div style="padding: 30px;">
          #{content}
        </div>
        <div style="border-top: 1px solid #e5e7eb; padding: 20px; text-align: center; font-size: 12px; color: #6b7280;">
          <p style="margin: 0;">© #{Date.current.year} #{account.name}</p>
        </div>
      </div>
    }
  end

  def apply_minimal_design(content, context)
    # Apply minimal design
    %{
      <div style="font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; max-width: 500px; margin: 0 auto; background: white;">
        <div style="padding: 40px 20px;">
          #{content}
        </div>
        <div style="padding: 20px; text-align: center; font-size: 12px; color: #9ca3af;">
          <p style="margin: 0;">#{account.name}</p>
        </div>
      </div>
    }
  end

  def interpolate_variables(content, contact)
    # Legacy method for backward compatibility
    context = build_rendering_context(contact)
    render_template_content(content, context)
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
end
