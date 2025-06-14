class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # Associations
  belongs_to :account
  has_many :campaigns, dependent: :destroy
  has_many :templates, dependent: :destroy

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
end
