# frozen_string_literal: true

class EmailAutomation < ApplicationRecord
  include AccountScoped
  include Auditable
  include Trackable
  include Searchable

  # Associations
  belongs_to :account
  has_many :automation_steps, -> { order(:step_order) }, dependent: :destroy
  has_many :automation_enrollments, dependent: :destroy
  has_many :enrolled_contacts, through: :automation_enrollments, source: :contact

  # Validations
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :trigger_type, inclusion: {
    in: %w[manual contact_subscribed contact_inactive cart_abandoned form_submitted tag_added]
  }
  validates :status, inclusion: { in: %w[draft active paused archived] }

  # Enums for better query interface
  enum :trigger_type, {
    manual: "manual",
    contact_subscribed: "contact_subscribed",
    contact_inactive: "contact_inactive",
    cart_abandoned: "cart_abandoned",
    form_submitted: "form_submitted",
    tag_added: "tag_added"
  }, prefix: :trigger

  enum :status, {
    draft: "draft",
    active: "active",
    paused: "paused",
    archived: "archived"
  }, prefix: true

  # Scopes
  scope :by_trigger_type, ->(type) { where(trigger_type: type) }
  scope :recently_active, -> { where("updated_at >= ?", 7.days.ago) }

  # Note: trigger_conditions is a jsonb column, no serialization needed

  # Callbacks
  before_save :validate_trigger_conditions
  after_update :handle_status_change

  # Class methods
  def self.searchable_fields
    %w[name description]
  end

  def self.triggers_for_event(event_type, context = {})
    active.where(trigger_type: event_type).select do |automation|
      automation.trigger_conditions_met?(context)
    end
  end

  # Instance methods
  def draft?
    status == "draft"
  end

  def active?
    status == "active"
  end

  def paused?
    status == "paused"
  end

  def archived?
    status == "archived"
  end

  def can_be_activated?
    draft? || paused?
  end

  def can_be_paused?
    active?
  end

  def activate!
    return false unless can_be_activated?

    update!(status: "active", activated_at: Time.current)
  end

  def pause!
    return false unless can_be_paused?

    update!(status: "paused", paused_at: Time.current)
  end

  def archive!
    update!(status: "archived", archived_at: Time.current)
  end

  def total_enrollments
    automation_enrollments.count
  end

  def active_enrollments
    automation_enrollments.active.count
  end

  def completed_enrollments
    automation_enrollments.completed.count
  end

  def completion_rate
    return 0 if total_enrollments == 0

    (completed_enrollments.to_f / total_enrollments * 100).round(2)
  end

  def average_completion_time
    completed = automation_enrollments.completed.where.not(completed_at: nil)
    return 0 if completed.empty?

    total_time = completed.sum do |enrollment|
      (enrollment.completed_at - enrollment.enrolled_at) / 1.day
    end

    (total_time / completed.count).round(2)
  end

  def trigger_conditions_met?(context = {})
    return true if trigger_conditions.blank?

    case trigger_type
    when "contact_subscribed"
      true # Always trigger for new subscriptions
    when "contact_inactive"
      contact = context[:contact]
      return false unless contact

      inactive_days = trigger_conditions["inactive_days"] || 90
      last_activity = contact.last_opened_at || contact.created_at
      (Date.current - last_activity.to_date).to_i >= inactive_days
    when "cart_abandoned"
      cart_value = context[:cart_value] || 0
      min_value = trigger_conditions["cart_value_min"] || 0
      abandoned_hours = trigger_conditions["abandoned_hours"] || 1

      cart_value >= min_value && context[:abandoned_at] <= abandoned_hours.hours.ago
    when "tag_added"
      tag_names = trigger_conditions["tag_names"] || []
      added_tags = context[:added_tags] || []

      (tag_names & added_tags).any?
    else
      true
    end
  end

  def enroll_contact!(contact, context = {})
    return false if automation_enrollments.active.exists?(contact: contact)

    enrollment = automation_enrollments.create!(
      contact: contact,
      status: "active",
      enrolled_at: Time.current,
      current_step: 1,
      context: context
    )

    # Schedule first step
    first_step = automation_steps.first
    if first_step
      first_step.schedule_for_enrollment(enrollment)
    end

    track_activity!("contact_enrolled", { contact_id: contact.id })
    enrollment
  end

  def performance_summary(period = 30.days)
    enrollments = automation_enrollments.where("enrolled_at >= ?", period.ago)

    {
      total_enrollments: enrollments.count,
      active_enrollments: enrollments.active.count,
      completed_enrollments: enrollments.completed.count,
      dropped_enrollments: enrollments.dropped.count,
      completion_rate: enrollments.any? ? (enrollments.completed.count.to_f / enrollments.count * 100).round(2) : 0,
      average_time_to_complete: calculate_average_completion_time(enrollments.completed),
      conversion_events: calculate_conversion_events(enrollments)
    }
  end

  def duplicate!(new_name = nil)
    new_automation = dup
    new_automation.name = new_name || "#{name} (Copy)"
    new_automation.status = "draft"
    new_automation.activated_at = nil
    new_automation.paused_at = nil
    new_automation.archived_at = nil

    transaction do
      new_automation.save!

      # Duplicate steps
      automation_steps.each do |step|
        new_step = step.dup
        new_step.email_automation = new_automation
        new_step.save!
      end

      new_automation
    end
  end

  private

  def validate_trigger_conditions
    return if trigger_conditions.blank?

    case trigger_type
    when "contact_inactive"
      unless trigger_conditions["inactive_days"].is_a?(Integer) && trigger_conditions["inactive_days"] > 0
        errors.add(:trigger_conditions, "inactive_days must be a positive integer")
      end
    when "cart_abandoned"
      unless trigger_conditions["cart_value_min"].is_a?(Numeric) && trigger_conditions["cart_value_min"] >= 0
        errors.add(:trigger_conditions, "cart_value_min must be a non-negative number")
      end
    when "tag_added"
      unless trigger_conditions["tag_names"].is_a?(Array) && trigger_conditions["tag_names"].any?
        errors.add(:trigger_conditions, "tag_names must be a non-empty array")
      end
    end
  end

  def handle_status_change
    if saved_change_to_status?
      case status
      when "active"
        track_activity!("activated")
      when "paused"
        track_activity!("paused")
      when "archived"
        track_activity!("archived")
      end
    end
  end

  def calculate_average_completion_time(completed_enrollments)
    return 0 if completed_enrollments.empty?

    total_time = completed_enrollments.sum do |enrollment|
      (enrollment.completed_at - enrollment.enrolled_at) / 1.hour
    end

    (total_time / completed_enrollments.count).round(2)
  end

  def calculate_conversion_events(enrollments)
    # This would track conversion events like purchases, sign-ups, etc.
    # For now, return a placeholder
    {
      total_conversions: 0,
      conversion_rate: 0,
      revenue_attributed: 0
    }
  end
end
