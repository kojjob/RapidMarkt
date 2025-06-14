class ContactTag < ApplicationRecord
  # Associations
  belongs_to :contact
  belongs_to :tag

  # Validations
  validates :contact_id, uniqueness: { scope: :tag_id }
end
