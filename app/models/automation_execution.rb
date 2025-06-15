# frozen_string_literal: true

class AutomationExecution < ApplicationRecord
  include Auditable

  # Associations
  belongs_to :automation_enrollment
  belongs_to :automation_step
  has_one :email_automation, through: :automation_step
  has_one :contact, through: :automation_enrollment

  # Validations
  validates :status, inclusion: { in: %w[scheduled executing completed failed cancelled skipped] }
  validates :scheduled_at, presence: true

  # Enums
  enum :status, {
    scheduled: "scheduled",
    executing: "executing",
    completed: "completed",
    failed: "failed",
    cancelled: "cancelled",
    skipped: "skipped"
  }, prefix: true

  # JSON serialization
  # Note: execution_data and error_details are jsonb columns, no serialization needed

  # Scopes
  scope :due_for_execution, -> { where(status: "scheduled").where("scheduled_at <= ?", Time.current) }
  scope :overdue, -> { where(status: "scheduled").where("scheduled_at < ?", 1.hour.ago) }
  scope :recent, -> { where("created_at >= ?", 7.days.ago) }

  # Callbacks
  before_update :set_execution_timestamps

  # Class methods
  def self.process_due_executions
    due_for_execution.find_each do |execution|
      ProcessAutomationExecutionJob.perform_later(execution.id)
    end
  end

  def self.cleanup_old_records(older_than = 6.months)
    where("created_at < ?", older_than.ago).destroy_all
  end

  # Instance methods
  def overdue?
    scheduled? && scheduled_at < 1.hour.ago
  end

  def can_execute?
    scheduled? && scheduled_at <= Time.current
  end

  def execute!
    return false unless can_execute?

    update!(status: "executing", started_at: Time.current)

    begin
      result = perform_execution

      if result[:success]
        complete_execution(result[:data])
      else
        fail_execution(result[:error])
      end
    rescue => e
      fail_execution(e.message, e.backtrace)
    end
  end

  def cancel!
    return false unless scheduled?

    update!(
      status: "cancelled",
      cancelled_at: Time.current,
      error_message: "Execution cancelled"
    )
  end

  def skip!(reason = nil)
    update!(
      status: "skipped",
      executed_at: Time.current,
      error_message: reason || "Execution skipped"
    )
  end

  def retry!
    return false unless failed?

    update!(
      status: "scheduled",
      scheduled_at: Time.current,
      started_at: nil,
      executed_at: nil,
      error_message: nil,
      error_details: nil,
      retry_count: (retry_count || 0) + 1
    )
  end

  def execution_duration
    return 0 unless started_at && executed_at

    executed_at - started_at
  end

  def should_retry?
    failed? && (retry_count || 0) < 3 && !permanent_failure?
  end

  def permanent_failure?
    return false unless error_details.present?

    permanent_errors = [
      "contact_unsubscribed",
      "template_not_found",
      "invalid_email_address"
    ]

    permanent_errors.include?(error_details["error_type"])
  end

  def execution_summary
    {
      step_type: automation_step.step_type,
      step_order: automation_step.step_order,
      status: status,
      scheduled_at: scheduled_at,
      executed_at: executed_at,
      duration: execution_duration,
      retry_count: retry_count || 0,
      error_message: error_message
    }
  end

  private

  def perform_execution
    case automation_step.step_type
    when "email"
      execute_email_step
    when "wait"
      execute_wait_step
    when "condition"
      execute_condition_step
    when "action"
      execute_action_step
    else
      { success: false, error: "Unknown step type: #{automation_step.step_type}" }
    end
  end

  def execute_email_step
    contact = automation_enrollment.contact

    # Check if contact can receive emails
    unless contact.can_receive_emails?
      return {
        success: false,
        error: "Contact cannot receive emails",
        error_type: "contact_unsubscribed"
      }
    end

    # Get template
    template = automation_step.email_template
    unless template
      return {
        success: false,
        error: "Email template not found",
        error_type: "template_not_found"
      }
    end

    # Create and send campaign
    campaign = create_automation_campaign(template, contact)

    if campaign
      { success: true, data: { campaign_id: campaign.id } }
    else
      { success: false, error: "Failed to create campaign" }
    end
  end

  def execute_wait_step
    # Wait step is just a delay - mark as completed
    { success: true, data: { waited_for: automation_step.delay_in_seconds } }
  end

  def execute_condition_step
    contact = automation_enrollment.contact

    if automation_step.can_execute_for_contact?(contact)
      { success: true, data: { condition_met: true } }
    else
      # Skip this path - mark as completed but don't advance
      { success: true, data: { condition_met: false, skipped: true } }
    end
  end

  def execute_action_step
    # Placeholder for custom actions (webhooks, API calls, etc.)
    { success: true, data: { action: "completed" } }
  end

  def create_automation_campaign(template, contact)
    campaign = email_automation.account.campaigns.create!(
      name: "#{email_automation.name} - Step #{automation_step.step_order}",
      subject: automation_step.custom_subject || template.subject,
      template: template,
      status: "sending",
      user: email_automation.account.users.first, # Use account owner
      automation_step_id: automation_step.id,
      automation_execution_id: id
    )

    # Add contact to campaign
    campaign.campaign_contacts.create!(
      contact: contact,
      status: "sending"
    )

    # Queue for sending
    CampaignSenderJob.perform_later(campaign.id)

    campaign
  rescue => e
    Rails.logger.error "Failed to create automation campaign: #{e.message}"
    nil
  end

  def complete_execution(data = {})
    update!(
      status: "completed",
      executed_at: Time.current,
      execution_data: data
    )

    # Advance enrollment to next step
    if automation_enrollment.advance_to_next_step!
      # Schedule next step
      next_step = automation_enrollment.next_step_object
      next_step&.schedule_for_enrollment(automation_enrollment)
    end
  end

  def fail_execution(error_message, error_details = nil)
    update!(
      status: "failed",
      executed_at: Time.current,
      error_message: error_message,
      error_details: {
        error_type: determine_error_type(error_message),
        details: error_details,
        timestamp: Time.current.iso8601
      }
    )

    # Mark enrollment as failed if this is a permanent failure
    if permanent_failure?
      automation_enrollment.fail!(error_message)
    end
  end

  def determine_error_type(error_message)
    case error_message.downcase
    when /unsubscribed|opted out/
      "contact_unsubscribed"
    when /template.*not found/
      "template_not_found"
    when /invalid.*email/
      "invalid_email_address"
    when /rate limit|throttle/
      "rate_limited"
    else
      "general_error"
    end
  end

  def set_execution_timestamps
    if status_changed?
      case status
      when "executing"
        self.started_at ||= Time.current
      when "completed", "failed", "cancelled", "skipped"
        self.executed_at ||= Time.current
      end
    end
  end
end
