# frozen_string_literal: true

class AutomationStep < ApplicationRecord
  include Auditable

  # Associations
  belongs_to :email_automation
  belongs_to :email_template, class_name: "Template", optional: true
  has_many :automation_executions, dependent: :destroy

  # Validations
  validates :step_type, inclusion: { in: %w[email wait condition action] }
  validates :step_order, presence: true, uniqueness: { scope: :email_automation_id }
  validates :delay_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :delay_unit, inclusion: { in: %w[minutes hours days weeks] }

  # Enums
  enum :step_type, {
    email: "email",
    wait: "wait",
    condition: "condition",
    action: "action"
  }, prefix: true

  enum :delay_unit, {
    minutes: "minutes",
    hours: "hours",
    days: "days",
    weeks: "weeks"
  }, prefix: :delay

  # JSON serialization
  serialize :conditions, coder: JSON

  # Scopes
  scope :ordered, -> { order(:step_order) }
  scope :email_steps, -> { where(step_type: "email") }
  scope :condition_steps, -> { where(step_type: "condition") }

  # Callbacks
  before_save :validate_step_configuration

  # Instance methods
  def delay_in_seconds
    case delay_unit
    when "minutes"
      delay_amount.minutes
    when "hours"
      delay_amount.hours
    when "days"
      delay_amount.days
    when "weeks"
      delay_amount.weeks
    else
      0
    end
  end

  def schedule_for_enrollment(enrollment)
    execution_time = delay_amount.zero? ? Time.current : delay_in_seconds.from_now

    AutomationExecution.create!(
      automation_enrollment: enrollment,
      automation_step: self,
      scheduled_at: execution_time,
      status: "scheduled"
    )
  end

  def can_execute_for_contact?(contact)
    return true if conditions.blank?

    # Evaluate conditions for the contact
    conditions.all? do |condition|
      evaluate_condition(condition, contact)
    end
  end

  def execution_count
    automation_executions.count
  end

  def success_count
    automation_executions.completed.count
  end

  def failure_count
    automation_executions.failed.count
  end

  def success_rate
    return 0 if execution_count == 0

    (success_count.to_f / execution_count * 100).round(2)
  end

  def next_step
    email_automation.automation_steps.where("step_order > ?", step_order).order(:step_order).first
  end

  def previous_step
    email_automation.automation_steps.where("step_order < ?", step_order).order(step_order: :desc).first
  end

  def duplicate
    dup.tap do |duplicate_step|
      duplicate_step.step_order = nil # Will be set when added to automation
    end
  end

  private

  def validate_step_configuration
    case step_type
    when "email"
      errors.add(:email_template, "is required for email steps") if email_template.blank? && custom_body.blank?
    when "condition"
      errors.add(:conditions, "are required for condition steps") if conditions.blank?
    when "wait"
      errors.add(:delay_amount, "must be greater than 0 for wait steps") if delay_amount <= 0
    end
  end

  def evaluate_condition(condition, contact)
    field = condition["field"]
    operator = condition["operator"]
    value = condition["value"]

    case field
    when "status"
      evaluate_status_condition(contact, operator, value)
    when "tag"
      evaluate_tag_condition(contact, operator, value)
    when "engagement_score"
      evaluate_engagement_condition(contact, operator, value)
    when "last_opened_at"
      evaluate_date_condition(contact.last_opened_at, operator, value)
    when "created_at"
      evaluate_date_condition(contact.created_at, operator, value)
    else
      true # Default to true for unknown conditions
    end
  end

  def evaluate_status_condition(contact, operator, value)
    case operator
    when "equals"
      contact.status == value
    when "not_equals"
      contact.status != value
    else
      false
    end
  end

  def evaluate_tag_condition(contact, operator, value)
    case operator
    when "has"
      contact.tags.exists?(name: value)
    when "does_not_have"
      !contact.tags.exists?(name: value)
    else
      false
    end
  end

  def evaluate_engagement_condition(contact, operator, value)
    engagement_score = contact.engagement_score || 0

    case operator
    when "greater_than"
      engagement_score > value.to_f
    when "less_than"
      engagement_score < value.to_f
    when "equals"
      engagement_score == value.to_f
    else
      false
    end
  end

  def evaluate_date_condition(date_value, operator, value)
    return false if date_value.blank?

    comparison_date = case value
    when "today"
                       Date.current
    when "yesterday"
                       1.day.ago.to_date
    when /^\d+_days_ago$/
                       days = value.split("_").first.to_i
                       days.days.ago.to_date
    else
                       Date.parse(value) rescue Date.current
    end

    case operator
    when "after"
      date_value.to_date > comparison_date
    when "before"
      date_value.to_date < comparison_date
    when "on"
      date_value.to_date == comparison_date
    else
      false
    end
  end
end
