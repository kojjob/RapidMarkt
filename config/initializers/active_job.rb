# frozen_string_literal: true

# Configuration for ActiveJob with Rails 8 Solid Queue (database-backed job processing)
Rails.application.configure do
  # Configure Active Job to use Solid Queue (Rails 8's database-backed queue)
  config.active_job.queue_adapter = :solid_queue

  # Queue configuration
  config.active_job.queue_name_prefix = Rails.env.production? ? "rapidmarkt_production" : "rapidmarkt_#{Rails.env}"

  # Default job settings
  config.active_job.default_queue_name = :default
  config.active_job.retry_jitter = 0.15

  # Log job arguments in development and test
  config.active_job.log_arguments = !Rails.env.production?

  # Configure job priority and queue mappings
  config.active_job.queue_name_delimiter = "_"
end

# Solid Queue configuration
Rails.application.config.after_initialize do
  # Configure Solid Queue settings for all environments
  if Rails.application.config.active_job.queue_adapter == :solid_queue
    Rails.application.config.solid_queue = {
      # Database configuration - uses the queue database
      connects_to: { database: { writing: :queue } },

      # Silence polling in production to reduce log noise
      silence_polling: Rails.env.production?,

      # Enable supervisor for automatic worker management
      supervisor: true,

      # Recurring jobs configuration file
      recurring_schedule_file: Rails.root.join("config", "recurring.yml"),

      # Shutdown timeout for graceful worker termination
      shutdown_timeout: 5.seconds,

      # Concurrency settings based on environment
      concurrency: Rails.env.production? ? 5 : 2
    }
  end
end

# Queue naming convention and priorities for Solid Queue
module QueuePriorities
  CRITICAL = :critical                    # System critical operations (immediate)
  AUTOMATION = :automation                # Automation executions (high priority)
  CAMPAIGNS = :campaigns                  # Campaign sending (high priority)
  ENRICHMENT = :enrichment               # Contact enrichment (medium priority)
  BULK_OPERATIONS = :bulk_operations     # Bulk operations (medium priority)
  AUTOMATION_SCHEDULER = :automation_scheduler # Automation scheduling (medium priority)
  MAINTENANCE = :maintenance             # System maintenance (low priority)
  DEFAULT = :default                     # Default queue (low priority)
end

# Job retry configuration for different types of failures
module JobRetryConfig
  # Retry configuration for different error types
  RETRY_STRATEGIES = {
    # Network/API errors - retry with exponential backoff
    "Faraday::Error" => { wait: :exponentially_longer, attempts: 5 },
    "Net::TimeoutError" => { wait: :exponentially_longer, attempts: 3 },

    # Database errors - retry quickly first, then slower
    "ActiveRecord::RecordNotFound" => { wait: 5.seconds, attempts: 2 },
    "ActiveRecord::StatementInvalid" => { wait: :exponentially_longer, attempts: 3 },

    # Email sending errors
    "Mail::SMTPError" => { wait: 1.hour, attempts: 3 },

    # Default for unknown errors
    "StandardError" => { wait: :exponentially_longer, attempts: 3 }
  }.freeze

  def self.for_error(error)
    error_class = error.class.name
    RETRY_STRATEGIES[error_class] || RETRY_STRATEGIES["StandardError"]
  end
end

# Performance monitoring for Solid Queue
if Rails.env.production?
  Rails.application.config.after_initialize do
    # Monitor job queue performance
    ActiveSupport::Notifications.subscribe "enqueue.active_job" do |_name, _started, _finished, _unique_id, data|
      Rails.logger.info "Job enqueued: #{data[:job].class.name} on queue #{data[:job].queue_name}"
    end

    ActiveSupport::Notifications.subscribe "perform.active_job" do |_name, started, finished, _unique_id, data|
      duration = finished - started
      Rails.logger.info "Job performed: #{data[:job].class.name} in #{duration.round(2)}s"

      # Alert if job takes too long
      if duration > 5.minutes
        Rails.logger.warn "Slow job detected: #{data[:job].class.name} took #{duration.round(2)}s"
      end
    end
  end
end
