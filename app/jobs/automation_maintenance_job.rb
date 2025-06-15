# frozen_string_literal: true

# Job to cleanup and maintain automation system health
class AutomationMaintenanceJob < ApplicationJob
  include Auditable

  queue_as :maintenance

  retry_on StandardError, attempts: 2

  def perform(maintenance_type = "all")
    Rails.logger.info "Starting automation maintenance: #{maintenance_type}"

    case maintenance_type
    when "cleanup"
      cleanup_old_data
    when "metrics"
      update_automation_metrics
    when "health_check"
      perform_health_checks
    when "optimize"
      optimize_automations
    when "all"
      cleanup_old_data
      update_automation_metrics
      perform_health_checks
      optimize_automations
    end

    Rails.logger.info "Completed automation maintenance: #{maintenance_type}"
  end

  private

  def cleanup_old_data
    Rails.logger.info "Starting automation data cleanup"

    # Clean up old audit logs (keep 6 months)
    old_audit_logs = AuditLog.where("created_at < ?", 6.months.ago)
    deleted_audits = old_audit_logs.delete_all
    Rails.logger.info "Deleted #{deleted_audits} old audit logs"

    # Clean up old contact activity logs (keep 1 year)
    old_activity_logs = ContactActivityLog.where("created_at < ?", 1.year.ago)
    deleted_activities = old_activity_logs.delete_all
    Rails.logger.info "Deleted #{deleted_activities} old activity logs"

    # Clean up completed automation executions (keep 3 months)
    old_executions = AutomationExecution.where(status: "completed")
                                       .where("completed_at < ?", 3.months.ago)
    deleted_executions = old_executions.delete_all
    Rails.logger.info "Deleted #{deleted_executions} old completed executions"

    # Clean up orphaned enrollments (no active executions and completed > 1 month ago)
    orphaned_enrollments = AutomationEnrollment
      .left_joins(:automation_executions)
      .where(status: "completed")
      .where("automation_enrollments.completed_at < ?", 1.month.ago)
      .where(automation_executions: { id: nil })

    deleted_enrollments = orphaned_enrollments.delete_all
    Rails.logger.info "Deleted #{deleted_enrollments} orphaned enrollments"
  end

  def update_automation_metrics
    Rails.logger.info "Updating automation metrics"

    EmailAutomation.active.find_each do |automation|
      update_automation_performance_metrics(automation)
    end
  end

  def update_automation_performance_metrics(automation)
    # Calculate enrollment metrics
    total_enrollments = automation.automation_enrollments.count
    active_enrollments = automation.automation_enrollments.where(status: "active").count
    completed_enrollments = automation.automation_enrollments.where(status: "completed").count

    # Calculate step completion rates
    total_executions = automation.automation_executions.count
    completed_executions = automation.automation_executions.where(status: "completed").count
    failed_executions = automation.automation_executions.where(status: [ "failed", "failed_permanently" ]).count

    completion_rate = total_executions > 0 ? (completed_executions.to_f / total_executions * 100).round(2) : 0
    failure_rate = total_executions > 0 ? (failed_executions.to_f / total_executions * 100).round(2) : 0

    # Calculate email metrics for email steps
    email_executions = automation.automation_executions
                                .joins(:automation_step)
                                .where(automation_steps: { step_type: "email" })
                                .where(status: "completed")

    total_emails_sent = email_executions.count

    # Update automation metrics
    automation.update!(
      metadata: automation.metadata.merge({
        performance_metrics: {
          total_enrollments: total_enrollments,
          active_enrollments: active_enrollments,
          completed_enrollments: completed_enrollments,
          completion_rate: completion_rate,
          failure_rate: failure_rate,
          total_emails_sent: total_emails_sent,
          last_metrics_update: Time.current
        }
      })
    )
  end

  def perform_health_checks
    Rails.logger.info "Performing automation health checks"

    issues = []

    # Check for stuck executions
    stuck_executions = AutomationExecution.where(status: "processing")
                                         .where("started_at < ?", 1.hour.ago)

    if stuck_executions.exists?
      issues << "Found #{stuck_executions.count} stuck executions"

      # Reset stuck executions
      stuck_executions.update_all(
        status: "failed",
        error_message: "Execution timeout - reset by maintenance job",
        failed_at: Time.current
      )
    end

    # Check for overdue waiting executions
    overdue_executions = AutomationExecution.where(status: "waiting")
                                           .where("scheduled_at < ?", 10.minutes.ago)

    if overdue_executions.exists?
      issues << "Found #{overdue_executions.count} overdue waiting executions"

      # Reschedule overdue executions
      overdue_executions.each do |execution|
        execution.update!(status: "pending", scheduled_at: Time.current)
        ProcessAutomationExecutionJob.perform_later(execution.id)
      end
    end

    # Check for automations with high failure rates
    EmailAutomation.active.each do |automation|
      metrics = automation.metadata&.dig("performance_metrics")
      next unless metrics

      failure_rate = metrics["failure_rate"] || 0
      if failure_rate > 25 # More than 25% failure rate
        issues << "Automation #{automation.id} has high failure rate: #{failure_rate}%"
      end
    end

    # Log health check results
    if issues.any?
      Rails.logger.warn "Automation health check found issues: #{issues.join('; ')}"

      # Optionally notify admins
      NotificationService.notify_automation_health_issues(issues)
    else
      Rails.logger.info "Automation health check completed successfully"
    end
  end

  def optimize_automations
    Rails.logger.info "Optimizing automations"

    EmailAutomation.active.find_each do |automation|
      optimize_automation_performance(automation)
    end
  end

  def optimize_automation_performance(automation)
    # Analyze step performance and suggest optimizations
    steps_needing_optimization = []

    automation.automation_steps.each do |step|
      step_executions = step.automation_executions.where("created_at >= ?", 30.days.ago)
      total_executions = step_executions.count

      next if total_executions < 10 # Need sufficient data

      failed_executions = step_executions.where(status: [ "failed", "failed_permanently" ]).count
      failure_rate = (failed_executions.to_f / total_executions * 100).round(2)

      if failure_rate > 15 # More than 15% failure rate
        steps_needing_optimization << {
          step_id: step.id,
          step_type: step.step_type,
          failure_rate: failure_rate,
          total_executions: total_executions
        }
      end
    end

    if steps_needing_optimization.any?
      # Update automation with optimization suggestions
      automation.update!(
        metadata: automation.metadata.merge({
          optimization_suggestions: {
            steps_needing_attention: steps_needing_optimization,
            last_optimization_check: Time.current,
            recommendations: generate_optimization_recommendations(steps_needing_optimization)
          }
        })
      )

      Rails.logger.info "Found optimization opportunities for automation #{automation.id}"
    end
  end

  def generate_optimization_recommendations(problem_steps)
    recommendations = []

    problem_steps.each do |step_data|
      case step_data[:step_type]
      when "email"
        recommendations << "Email step #{step_data[:step_id]} has #{step_data[:failure_rate]}% failure rate. Check email template and delivery settings."
      when "webhook"
        recommendations << "Webhook step #{step_data[:step_id]} has #{step_data[:failure_rate]}% failure rate. Verify webhook endpoint reliability."
      when "condition"
        recommendations << "Condition step #{step_data[:step_id]} has #{step_data[:failure_rate]}% failure rate. Review condition logic and data availability."
      else
        recommendations << "Step #{step_data[:step_id]} (#{step_data[:step_type]}) needs attention with #{step_data[:failure_rate]}% failure rate."
      end
    end

    recommendations
  end
end
