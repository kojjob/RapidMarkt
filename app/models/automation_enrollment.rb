# frozen_string_literal: true

class AutomationEnrollment < ApplicationRecord
  include Auditable
  include Trackable

  # Associations
  belongs_to :email_automation
  belongs_to :contact
  has_many :automation_executions, dependent: :destroy

  # Validations
  validates :status, inclusion: { in: %w[active paused completed dropped failed] }
  validates :contact_id, uniqueness: {
    scope: :email_automation_id,
    conditions: -> { where(status: %w[active paused]) },
    message: "is already enrolled in this automation"
  }

  # Enums
  enum :status, {
    active: "active",
    paused: "paused",
    completed: "completed",
    dropped: "dropped",
    failed: "failed"
  }, prefix: true

  # JSON serialization
  serialize :context, coder: JSON

  # Scopes
  scope :recent, -> { where("enrolled_at >= ?", 30.days.ago) }
  scope :long_running, -> { where("enrolled_at <= ?", 90.days.ago) }

  # Callbacks
  before_create :set_enrollment_defaults
  after_update :track_status_changes

  # Instance methods
  def duration
    end_time = completed_at || paused_at || Time.current
    return 0 unless enrolled_at

    ((end_time - enrolled_at) / 1.day).round(2)
  end

  def progress_percentage
    total_steps = email_automation.automation_steps.count
    return 0 if total_steps == 0

    completed_steps = automation_executions.completed.count
    (completed_steps.to_f / total_steps * 100).round(2)
  end

  def current_step_object
    email_automation.automation_steps.find_by(step_order: current_step)
  end

  def next_step_object
    email_automation.automation_steps.where("step_order > ?", current_step).order(:step_order).first
  end

  def can_advance?
    active? && next_step_object.present?
  end

  def advance_to_next_step!
    return false unless can_advance?

    self.current_step += 1

    if next_step_object
      save!
      true
    else
      complete!
      false
    end
  end

  def complete!
    update!(
      status: "completed",
      completed_at: Time.current
    )

    track_activity!("completed", { duration: duration })
  end

  def pause!(reason = nil)
    return false unless active?

    update!(
      status: "paused",
      paused_at: Time.current,
      pause_reason: reason
    )

    # Cancel any scheduled executions
    automation_executions.scheduled.update_all(status: "cancelled")

    track_activity!("paused", { reason: reason })
  end

  def resume!
    return false unless paused?

    update!(
      status: "active",
      paused_at: nil,
      pause_reason: nil
    )

    # Reschedule current step if needed
    if current_step_object
      current_step_object.schedule_for_enrollment(self)
    end

    track_activity!("resumed")
  end

  def drop!(reason = nil)
    update!(
      status: "dropped",
      dropped_at: Time.current,
      drop_reason: reason
    )

    # Cancel any scheduled executions
    automation_executions.scheduled.update_all(status: "cancelled")

    track_activity!("dropped", { reason: reason })
  end

  def fail!(error_message = nil)
    update!(
      status: "failed",
      failed_at: Time.current,
      error_message: error_message
    )

    track_activity!("failed", { error: error_message })
  end

  def execution_history
    automation_executions.includes(:automation_step)
                         .order(:created_at)
                         .map do |execution|
      {
        step_order: execution.automation_step.step_order,
        step_type: execution.automation_step.step_type,
        status: execution.status,
        scheduled_at: execution.scheduled_at,
        executed_at: execution.executed_at,
        error_message: execution.error_message
      }
    end
  end

  def time_in_automation
    if completed?
      completed_at - enrolled_at
    elsif dropped? || failed?
      (dropped_at || failed_at) - enrolled_at
    else
      Time.current - enrolled_at
    end
  end

  def engagement_during_automation
    # Calculate engagement metrics during automation period
    campaign_interactions = contact.campaign_contacts
                                  .joins(:campaign)
                                  .where("campaigns.created_at >= ?", enrolled_at)

    {
      emails_received: campaign_interactions.count,
      emails_opened: campaign_interactions.where.not(opened_at: nil).count,
      emails_clicked: campaign_interactions.where.not(clicked_at: nil).count,
      last_interaction: campaign_interactions.maximum(:opened_at) || campaign_interactions.maximum(:sent_at)
    }
  end

  private

  def set_enrollment_defaults
    self.enrolled_at ||= Time.current
    self.current_step ||= 1
    self.context ||= {}
  end

  def track_status_changes
    if saved_change_to_status?
      previous_status = saved_changes["status"][0]
      current_status = saved_changes["status"][1]

      track_activity!("status_changed", {
        from: previous_status,
        to: current_status,
        step: current_step
      })
    end
  end
end
