class User < ApplicationRecord
  include Authorization
  
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  belongs_to :account
  has_many :campaigns, dependent: :destroy
  has_many :templates, dependent: :destroy
  has_many :user_sessions, dependent: :destroy
  has_many :audit_logs, dependent: :destroy

  # Validations
  validates :first_name, :last_name, presence: true
  validates :role, inclusion: { in: %w[owner admin member viewer] }
  validates :email, uniqueness: { scope: :account_id }
  validates :status, inclusion: { in: %w[active inactive suspended] }

  # Callbacks
  before_create :set_default_status
  after_create :create_initial_audit_log
  after_update :log_role_changes

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :admins, -> { where(role: [ "owner", "admin" ]) }
  scope :members, -> { where(role: "member") }
  scope :viewers, -> { where(role: "viewer") }
  scope :by_role, ->(role) { where(role: role) }

  # Methods
  def full_name
    "#{first_name} #{last_name}".strip
  end

  def display_name
    full_name.present? ? full_name : email.split('@').first.titleize
  end

  def admin?
    role.in?([ "owner", "admin" ])
  end

  def owner?
    role == "owner"
  end

  def member?
    role == "member"
  end

  def viewer?
    role == "viewer"
  end

  def active?
    status == "active"
  end

  def inactive?
    status == "inactive"
  end

  def suspended?
    status == "suspended"
  end

  # Security methods
  def can_change_role_of?(other_user)
    return false unless can?(:change_roles, :users)
    return false if other_user.owner? && !owner?
    return false if other_user.account_id != account_id
    
    higher_role_than?(other_user)
  end

  def can_invite_users?
    can?(:invite, :users) && account.active?
  end

  def can_access_billing?
    can?(:billing, :account)
  end

  def can_manage_team?
    can?(:team_management, :account)
  end

  # Activity tracking
  def last_active_at
    user_sessions.maximum(:updated_at) || updated_at
  end

  def online?
    last_active_at > 15.minutes.ago
  end

  # Account relationship helpers
  def teammates
    account.users.where.not(id: id)
  end

  def account_owner
    account.owner
  end

  def is_account_owner?
    self == account_owner
  end

  private

  def set_default_status
    self.status ||= "active"
  end

  def create_initial_audit_log
    audit_logs.create!(
      action: "user_created",
      details: {
        email: email,
        role: role,
        name: full_name
      },
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  end

  def log_role_changes
    if saved_change_to_role?
      old_role, new_role = saved_change_to_role
      audit_logs.create!(
        action: "role_changed",
        details: {
          old_role: old_role,
          new_role: new_role,
          changed_by: Current.user&.email
        },
        ip_address: Current.ip_address,
        user_agent: Current.user_agent
      )
    end
  end
end
