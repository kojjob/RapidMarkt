class Template < ApplicationRecord
  # Associations
  belongs_to :account
  has_many :campaigns, dependent: :nullify
  
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subject, presence: true, length: { maximum: 255 }
  validates :body, presence: true
  validates :template_type, inclusion: { in: %w[email newsletter promotional transactional] }
  validates :status, inclusion: { in: %w[draft active archived] }
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :draft, -> { where(status: 'draft') }
  scope :archived, -> { where(status: 'archived') }
  scope :by_type, ->(type) { where(template_type: type) }
  scope :search, ->(query) {
    where("name ILIKE ? OR subject ILIKE ?", "%#{query}%", "%#{query}%")
  }
  
  # Methods
  def active?
    status == 'active'
  end
  
  def draft?
    status == 'draft'
  end
  
  def archived?
    status == 'archived'
  end
  
  def activate!
    update!(status: 'active')
  end
  
  def archive!
    update!(status: 'archived')
  end
  
  def duplicate
    dup.tap do |template|
      template.name = "#{name} (Copy)"
      template.status = 'draft'
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
      'contact.first_name' => 'John',
      'contact.last_name' => 'Doe',
      'contact.email' => 'john.doe@example.com',
      'contact.full_name' => 'John Doe',
      'account.name' => account.name,
      'unsubscribe_url' => '[UNSUBSCRIBE_URL]',
      'current_date' => Date.current.strftime('%B %d, %Y')
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
    
    [subject, body].each do |content|
      next if content.blank?
      
      variables += content.scan(/\{\{\s*([^}]+)\s*\}\}/).flatten
    end
    
    variables.uniq.sort
  end
  
  private
  
  def interpolate_variables(content, contact)
    return content if content.blank?
    
    variables = {
      'contact.first_name' => contact.first_name,
      'contact.last_name' => contact.last_name,
      'contact.email' => contact.email,
      'contact.full_name' => contact.full_name,
      'account.name' => account.name,
      'unsubscribe_url' => generate_unsubscribe_url(contact),
      'current_date' => Date.current.strftime('%B %d, %Y')
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
end
