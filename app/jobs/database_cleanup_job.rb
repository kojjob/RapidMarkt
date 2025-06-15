# frozen_string_literal: true

class DatabaseCleanupJob < ApplicationJob
  queue_as QueuePriorities::MAINTENANCE

  def perform
    Rails.logger.info "Starting database cleanup at #{Time.current}"

    cleanup_results = {
      audit_logs_cleaned: 0,
      old_executions_cleaned: 0,
      orphaned_records_cleaned: 0,
      cache_entries_cleaned: 0
    }

    # Clean up old audit logs (older than 6 months)
    old_audit_logs = AuditLog.where("created_at < ?", 6.months.ago)
    cleanup_results[:audit_logs_cleaned] = old_audit_logs.count
    old_audit_logs.delete_all

    # Clean up old automation executions (older than 3 months)
    old_executions = AutomationExecution.where("created_at < ?", 3.months.ago)
    cleanup_results[:old_executions_cleaned] = old_executions.count
    old_executions.delete_all

    # Clean up orphaned campaign contacts (campaigns deleted but contacts remain)
    orphaned_campaign_contacts = CampaignContact.left_joins(:campaign)
                                              .where(campaigns: { id: nil })
    cleanup_results[:orphaned_records_cleaned] = orphaned_campaign_contacts.count
    orphaned_campaign_contacts.delete_all

    # Clean up Solid Cache entries (let Solid Cache handle its own cleanup)
    # This is handled automatically by Solid Cache based on max_age and max_size settings

    # Clean up temporary files older than 1 day
    cleanup_temp_files

    # Vacuum and analyze database tables for better performance
    optimize_database_performance

    Rails.logger.info "Database cleanup completed: #{cleanup_results}"

    # Create audit log for cleanup
    AuditLog.create!(
      action: "database_cleanup",
      details: "Database cleanup completed: #{cleanup_results}",
      resource_type: "System",
      user: nil,
      account: nil
    )

    cleanup_results
  rescue => e
    Rails.logger.error "Database cleanup failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Re-raise for job retry mechanism
    raise e
  end

  private

  def cleanup_temp_files
    temp_dir = Rails.root.join("tmp", "storage")
    return unless temp_dir.exist?

    old_files = Dir.glob(temp_dir.join("**", "*"))
                  .select { |f| File.file?(f) }
                  .select { |f| File.mtime(f) < 1.day.ago }

    old_files.each do |file|
      File.delete(file)
    rescue => e
      Rails.logger.warn "Failed to delete temp file #{file}: #{e.message}"
    end

    Rails.logger.info "Cleaned up #{old_files.count} temporary files"
  end

  def optimize_database_performance
    # Only run VACUUM and ANALYZE in PostgreSQL
    return unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"

    # Get list of tables to optimize
    tables_to_optimize = %w[
      audit_logs
      automation_executions
      automation_enrollments
      campaigns
      campaign_contacts
      contacts
      templates
    ]

    tables_to_optimize.each do |table|
      begin
        # ANALYZE to update table statistics
        ActiveRecord::Base.connection.execute("ANALYZE #{table}")
        Rails.logger.info "Analyzed table: #{table}"
      rescue => e
        Rails.logger.warn "Failed to analyze table #{table}: #{e.message}"
      end
    end
  end
end
