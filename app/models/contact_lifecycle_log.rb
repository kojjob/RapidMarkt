# frozen_string_literal: true

class ContactLifecycleLog < ApplicationRecord
  include Auditable

  # Associations
  belongs_to :contact
  belongs_to :user, optional: true

  # Validations
  validates :to_stage, presence: true
  validates :to_stage, inclusion: { in: %w[lead prospect customer advocate churned] }
  validates :from_stage, inclusion: { in: %w[lead prospect customer advocate churned] }, allow_blank: true

  # Scopes
  scope :recent, -> { where("created_at >= ?", 30.days.ago) }
  scope :for_stage, ->(stage) { where(to_stage: stage) }
  scope :from_stage, ->(stage) { where(from_stage: stage) }
  scope :ordered, -> { order(created_at: :desc) }

  # Instance methods
  def stage_change_description
    if from_stage.present?
      "#{from_stage.humanize} → #{to_stage.humanize}"
    else
      "Set to #{to_stage.humanize}"
    end
  end

  def progression?
    return false unless from_stage.present?

    stage_order = %w[lead prospect customer advocate]
    from_index = stage_order.index(from_stage)
    to_index = stage_order.index(to_stage)

    return false unless from_index && to_index

    to_index > from_index
  end

  def regression?
    return false unless from_stage.present?

    stage_order = %w[lead prospect customer advocate]
    from_index = stage_order.index(from_stage)
    to_index = stage_order.index(to_stage)

    return false unless from_index && to_index

    to_index < from_index
  end

  def churned?
    to_stage == "churned"
  end

  def time_since_change
    Time.current - created_at
  end

  def days_since_change
    (time_since_change / 1.day).round
  end
end
