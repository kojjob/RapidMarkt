class CampaignContact < ApplicationRecord
  # Associations
  belongs_to :campaign
  belongs_to :contact

  # Validations
  validates :campaign_id, uniqueness: { scope: :contact_id }

  # Scopes
  scope :sent, -> { where.not(sent_at: nil) }
  scope :opened, -> { where.not(opened_at: nil) }
  scope :clicked, -> { where.not(clicked_at: nil) }
  scope :bounced, -> { where.not(bounced_at: nil) }
  scope :unsubscribed, -> { where.not(unsubscribed_at: nil) }

  # Methods
  def sent?
    sent_at.present?
  end

  def opened?
    opened_at.present?
  end

  def clicked?
    clicked_at.present?
  end

  def bounced?
    bounced_at.present?
  end

  def unsubscribed?
    unsubscribed_at.present?
  end

  def mark_as_sent!
    update!(sent_at: Time.current)
  end

  def mark_as_opened!
    update!(opened_at: Time.current) unless opened?
  end

  def mark_as_clicked!
    update!(clicked_at: Time.current) unless clicked?
    mark_as_opened! unless opened?
  end

  def mark_as_bounced!
    update!(bounced_at: Time.current)
  end

  def mark_as_unsubscribed!
    update!(unsubscribed_at: Time.current)
    contact.unsubscribe!
  end

  def engagement_score
    score = 0
    score += 1 if sent?
    score += 2 if opened?
    score += 3 if clicked?
    score -= 1 if bounced?
    score -= 2 if unsubscribed?
    score
  end
end
