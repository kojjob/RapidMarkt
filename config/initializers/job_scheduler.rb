# frozen_string_literal: true

# Job scheduler configuration for recurring automation tasks using Solid Queue
# Solid Queue is the modern Rails job queue system that comes with Rails 8

Rails.application.config.after_initialize do
  # Configure Solid Queue for background job processing
  Rails.application.configure do
    config.active_job.queue_adapter = :solid_queue
  end

  # Define recurring jobs using a simple scheduler
  # Note: For production, consider using gems like 'whenever' for cron-like scheduling
  recurring_jobs = [
    # Process scheduled automations every minute
    {
      name: "ProcessScheduledAutomations",
      job_class: "ProcessScheduledAutomationsJob",
      interval: 1.minute,
      queue: "automation_scheduler"
    },

    # Maintenance tasks every hour
    {
      name: "AutomationMaintenance",
      job_class: "AutomationMaintenanceJob",
      interval: 1.hour,
      queue: "maintenance",
      args: ["cleanup"]
    },

    # Full maintenance every 6 hours
    {
      name: "FullAutomationMaintenance",
      job_class: "AutomationMaintenanceJob",
      interval: 6.hours,
      queue: "maintenance",
      args: ["all"]
    },

    # Process scheduled campaigns every 5 minutes
    {
      name: "ProcessScheduledCampaigns",
      job_class: "ProcessScheduledCampaignsJob",
      interval: 5.minutes,
      queue: "campaigns"
    },

    # Contact enrichment queue processing every 15 minutes
    {
      name: "ProcessContactEnrichmentQueue",
      job_class: "ProcessContactEnrichmentQueueJob",
      interval: 15.minutes,
      queue: "enrichment"
    },

    # Analytics update every 30 minutes
    {
      name: "UpdateAnalytics",
      job_class: "AnalyticsProcessorJob",
      interval: 30.minutes,
      queue: "default"
    },

    # Daily reporting at midnight (run every 24 hours)
    {
      name: "DailyReporting",
      job_class: "DatabaseCleanupJob",
      interval: 24.hours,
      queue: "default"
    }
  ]

  # Schedule recurring jobs using Solid Queue
  recurring_jobs.each do |job_config|
    begin
      job_class = job_config[:job_class].constantize

      # Schedule the job to run at the specified interval
      # Note: This is a simple implementation. For production, use proper cron scheduling
      Rails.logger.info "Configured recurring job: #{job_config[:name]} (#{job_config[:interval]})"

      # You can manually trigger these jobs or set up proper cron scheduling
      # Example: job_class.set(queue: job_config[:queue]).perform_later(*job_config[:args] || [])

    rescue => e
      Rails.logger.error "Failed to configure recurring job #{job_config[:name]}: #{e.message}"
    end
  end
end

# Alternative configuration using 'whenever' gem for production cron scheduling
# This would go in config/schedule.rb if using whenever gem
class JobScheduler
  def self.configure_whenever
    # This method would be called from config/schedule.rb
    # Example whenever configuration for Solid Queue:

    # Process scheduled automations every minute
    every 1.minute do
      runner "ProcessScheduledAutomationsJob.set(queue: 'automation_scheduler').perform_later"
    end

    # Maintenance tasks every hour
    every 1.hour do
      runner "AutomationMaintenanceJob.set(queue: 'maintenance').perform_later('cleanup')"
    end

    # Full maintenance every 6 hours
    every 6.hours do
      runner "AutomationMaintenanceJob.set(queue: 'maintenance').perform_later('all')"
    end

    # Process scheduled campaigns every 5 minutes
    every 5.minutes do
      runner "ProcessScheduledCampaignsJob.set(queue: 'campaigns').perform_later"
    end

    # Contact enrichment processing every 15 minutes
    every 15.minutes do
      runner "ProcessContactEnrichmentQueueJob.set(queue: 'enrichment').perform_later"
    end

    # Analytics update every 30 minutes
    every 30.minutes do
      runner "AnalyticsProcessorJob.set(queue: 'default').perform_later"
    end

    # Daily reporting at midnight
    every 1.day, at: "12:00 am" do
      runner "DatabaseCleanupJob.set(queue: 'default').perform_later"
    end

    # Weekly optimization on Sundays at 2 AM
    every :sunday, at: "2:00 am" do
      runner "AutomationMaintenanceJob.set(queue: 'maintenance').perform_later('weekly_optimization')"
    end
  end

  # Manual job scheduling methods for development/testing
  def self.schedule_all_jobs
    ProcessScheduledAutomationsJob.set(queue: 'automation_scheduler').perform_later
    ProcessScheduledCampaignsJob.set(queue: 'campaigns').perform_later
    ProcessContactEnrichmentQueueJob.set(queue: 'enrichment').perform_later
    AnalyticsProcessorJob.set(queue: 'default').perform_later
  end

  def self.schedule_maintenance
    AutomationMaintenanceJob.set(queue: 'maintenance').perform_later('cleanup')
  end
end
