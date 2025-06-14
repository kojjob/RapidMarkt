class Account < ApplicationRecord
  # Associations
  has_many :users, dependent: :destroy
  has_one :subscription, dependent: :destroy
  has_many :campaigns, dependent: :destroy
  has_many :contacts, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :tags, dependent: :destroy

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
  scope :active, -> { where(status: "active") }
  scope :by_plan, ->(plan) { where(plan: plan) }

  # Methods
  def owner
    users.find_by(role: "owner")
  end

  def active?
    status == "active"
  end

  def suspended?
    status == "suspended"
  end

  def cancelled?
    status == "cancelled"
  end

  def plan_limits
    case plan
    when "free"
      { contacts: 100, campaigns_per_month: 5, templates: 3, team_members: 1 }
    when "starter"
      { contacts: 1000, campaigns_per_month: 50, templates: 10, team_members: 3 }
    when "professional" 
      { contacts: 10000, campaigns_per_month: 200, templates: 50, team_members: 10 }
    when "enterprise"
      { contacts: Float::INFINITY, campaigns_per_month: Float::INFINITY, templates: Float::INFINITY, team_members: Float::INFINITY }
    end
  end
  
  # SME-focused helper methods
  def can_have_team_members?
    plan_limits[:team_members] > users.count
  end
  
  def is_solo_business?
    users.count == 1
  end
  
  def team_size
    users.active.count
  end
  
  def indie_friendly_plan?
    %w[free starter].include?(plan)
  end

  private

  def normalize_subdomain
    self.subdomain = subdomain&.downcase&.strip
  end
end
