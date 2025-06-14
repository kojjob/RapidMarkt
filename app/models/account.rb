class Account < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :templates, dependent: :destroy
  
  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :subdomain, presence: true, uniqueness: { case_sensitive: false },
                       format: { with: /\A[a-z0-9\-]+\z/, message: "can only contain lowercase letters, numbers, and hyphens" },
                       length: { minimum: 3, maximum: 30 }
  validates :plan, inclusion: { in: %w[free starter professional enterprise] }
  validates :status, inclusion: { in: %w[active suspended cancelled] }
  
  # Callbacks
  before_validation :normalize_subdomain
  
  # Scopes
  scope :active, -> { where(status: 'active') }
  scope :by_plan, ->(plan) { where(plan: plan) }
  
  # Methods
  def owner
    users.find_by(role: 'owner')
  end
  
  def active?
    status == 'active'
  end
  
  def suspended?
    status == 'suspended'
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  def plan_limits
    case plan
    when 'free'
      { contacts: 100, campaigns_per_month: 5, templates: 3 }
    when 'starter'
      { contacts: 1000, campaigns_per_month: 50, templates: 10 }
    when 'professional'
      { contacts: 10000, campaigns_per_month: 200, templates: 50 }
    when 'enterprise'
      { contacts: Float::INFINITY, campaigns_per_month: Float::INFINITY, templates: Float::INFINITY }
    end
  end
  
  private
  
  def normalize_subdomain
    self.subdomain = subdomain&.downcase&.strip
  end
end
