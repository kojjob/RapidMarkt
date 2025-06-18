class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  belongs_to :account

  # Validations
  validates :first_name, :last_name, presence: true
  validates :role, inclusion: { in: %w[owner admin member] }

  # Scopes
  scope :admins, -> { where(role: [ "owner", "admin" ]) }
  scope :members, -> { where(role: "member") }

  # Methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def admin?
    role.in?([ "owner", "admin" ])
  end

  def owner?
    role == "owner"
  end

  def can_use_ai_features?
    # For now, all users can use AI features
    # This can be extended to check subscription plans, feature flags, etc.
    true
  end
end
