# frozen_string_literal: true

# Cron-like job scheduler configuration for recurring automation tasks
# This would work with gems like 'whenever' or 'sidekiq-cron'

require "sidekiq"

# Configure recurring jobs using sidekiq-cron
if defined?(Sidekiq::Cron::Job)
  Rails.application.config.after_initialize do
    # Define recurring jobs
    recurring_jobs = {
      # Process scheduled automations every minute
      "ProcessScheduledAutomations" => {
        job_class: "ProcessScheduledAutomationsJob",
        cron: "* * * * *", # Every minute
        queue: "automation_scheduler"
      },

      # Maintenance tasks every hour
      "AutomationMaintenance" => {
        job_class: "AutomationMaintenanceJob",
        cron: "0 * * * *", # Every hour at minute 0
        queue: "maintenance",
        args: [ "cleanup" ]
      },

      # Full maintenance every 6 hours
      "FullAutomationMaintenance" => {
        job_class: "AutomationMaintenanceJob",
        cron: "0 */6 * * *", # Every 6 hours
        queue: "maintenance",
        args: [ "all" ]
      },

      # Process scheduled campaigns every 5 minutes
      "ProcessScheduledCampaigns" => {
        job_class: "ProcessScheduledCampaignsJob",
        cron: "*/5 * * * *", # Every 5 minutes
        queue: "campaigns"
      },

      # Contact enrichment queue processing every 15 minutes
      "ProcessContactEnrichmentQueue" => {
        job_class: "ProcessContactEnrichmentQueueJob",
        cron: "*/15 * * * *", # Every 15 minutes
        queue: "enrichment"
      },

      # Analytics update every 30 minutes
      "UpdateAnalytics" => {
        job_class: "UpdateAnalyticsJob",
        cron: "*/30 * * * *", # Every 30 minutes
        queue: "default"
      },

      # Daily reporting at midnight
      "DailyReporting" => {
        job_class: "DailyReportingJob",
        cron: "0 0 * * *", # Daily at midnight
        queue: "default"
      },

      # Weekly optimization analysis on Sundays
      "WeeklyOptimization" => {
        job_class: "WeeklyOptimizationJob",
        cron: "0 2 * * 0", # Sundays at 2 AM
        queue: "maintenance"
      }
    }

    # Load recurring jobs
    recurring_jobs.each do |name, config|
      begin
        Sidekiq::Cron::Job.load_from_hash({
          name => {
            "class" => config[:job_class],
            "cron" => config[:cron],
            "queue" => config[:queue],
            "args" => config[:args] || []
          }
        })

        Rails.logger.info "Loaded recurring job: #{name}"
      rescue => e
        Rails.logger.error "Failed to load recurring job #{name}: #{e.message}"
      end
    end
  end
end

# Alternative configuration using 'whenever' gem
# This would go in config/schedule.rb if using whenever
class JobScheduler
  def self.configure_whenever
    # This method would be called from config/schedule.rb

    # Process scheduled automations every minute
    every 1.minute do
      runner "ProcessScheduledAutomationsJob.perform_later"
    end

    # Maintenance tasks every hour
    every 1.hour do
      runner "AutomationMaintenanceJob.perform_later('cleanup')"
    end

    # Full maintenance every 6 hours
    every 6.hours do
      runner "AutomationMaintenanceJob.perform_later('all')"
    end

    # Process scheduled campaigns every 5 minutes
    every 5.minutes do
      runner "ProcessScheduledCampaignsJob.perform_later"
    end

    # Contact enrichment processing every 15 minutes
    every 15.minutes do
      runner "ProcessContactEnrichmentQueueJob.perform_later"
    end

    # Analytics update every 30 minutes
    every 30.minutes do
      runner "UpdateAnalyticsJob.perform_later"
    end

    # Daily reporting at midnight
    every 1.day, at: "12:00 am" do
      runner "DailyReportingJob.perform_later"
    end

    # Weekly optimization on Sundays at 2 AM
    every :sunday, at: "2:00 am" do
      runner "WeeklyOptimizationJob.perform_later"
    end
  end
end
