class Tag < ApplicationRecord
  belongs_to :account
  has_many :contact_tags, dependent: :destroy
  has_many :contacts, through: :contact_tags
  has_many :campaign_tags, dependent: :destroy
  has_many :campaigns, through: :campaign_tags
  
  # Validations
  validates :name, presence: true, length: { minimum: 1, maximum: 50 }
  validates :name, uniqueness: { scope: :account_id, case_sensitive: false }
  validates :color, format: { with: /\A#[0-9A-Fa-f]{6}\z/, message: "must be a valid hex color" }, allow_blank: true
  
  # Callbacks
  before_validation :set_default_color, if: -> { color.blank? }
  before_validation :normalize_name
  
  # Scopes
  scope :ordered, -> { order(:name) }
  
  private
  
  def set_default_color
    self.color = "#3B82F6" # Default blue color
  end
  
  def normalize_name
    self.name = name&.strip&.downcase
  end
end
