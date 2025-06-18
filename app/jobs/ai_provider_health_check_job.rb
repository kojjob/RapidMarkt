class AiProviderHealthCheckJob < ApplicationJob
  queue_as :ai_monitoring
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(provider_id = nil)
    if provider_id
      check_single_provider(provider_id)
    else
      check_all_providers
    end
  end
  
  private
  
  def check_single_provider(provider_id)
    provider = AiProvider.find(provider_id)
    
    Rails.logger.info "Starting health check for provider: #{provider.name} (#{provider.provider_type})"
    
    start_time = Time.current
    
    begin
      # Perform the health check
      is_healthy = provider.health_check
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      # Update provider status
      provider.update!(
        health_status: is_healthy ? 'healthy' : 'unhealthy',
        last_health_check: Time.current,
        last_error: is_healthy ? nil : 'Health check failed'
      )
      
      # Log the health check result
      log_health_check_result(provider, is_healthy, response_time)
      
      # Handle unhealthy provider
      if !is_healthy
        handle_unhealthy_provider(provider)
      else
        handle_healthy_provider(provider)
      end
      
      Rails.logger.info "Health check completed for #{provider.name}: #{is_healthy ? 'HEALTHY' : 'UNHEALTHY'} (#{response_time}ms)"
      
    rescue => error
      response_time = ((Time.current - start_time) * 1000).round(2)
      
      # Update provider with error status
      provider.update!(
        health_status: 'unhealthy',
        last_health_check: Time.current,
        last_error: error.message
      )
      
      # Log the error
      log_health_check_result(provider, false, response_time, error.message)
      
      # Handle the error
      handle_unhealthy_provider(provider, error)
      
      Rails.logger.error "Health check failed for #{provider.name}: #{error.message}"
    end
  end
  
  def check_all_providers
    providers = AiProvider.active
    
    Rails.logger.info "Starting health check for #{providers.count} active providers"
    
    results = {
      total_checked: providers.count,
      healthy_count: 0,
      unhealthy_count: 0,
      error_count: 0,
      results: []
    }
    
    providers.find_each do |provider|
      begin
        check_single_provider(provider.id)
        
        # Reload to get updated status
        provider.reload
        
        if provider.health_status == 'healthy'
          results[:healthy_count] += 1
        else
          results[:unhealthy_count] += 1
        end
        
        results[:results] << {
          provider_id: provider.id,
          provider_name: provider.name,
          provider_type: provider.provider_type,
          status: provider.health_status,
          last_check: provider.last_health_check,
          response_time: provider.metadata&.dig('last_response_time')
        }
        
        # Small delay between checks to avoid overwhelming providers
        sleep(1) if providers.count > 1
        
      rescue => error
        results[:error_count] += 1
        results[:results] << {
          provider_id: provider.id,
          provider_name: provider.name,
          provider_type: provider.provider_type,
          status: 'error',
          error: error.message
        }
        
        Rails.logger.error "Failed to check provider #{provider.name}: #{error.message}"
      end
    end
    
    # Store aggregated results
    Rails.cache.write(
      'ai_providers:health_check_summary',
      results,
      expires_in: 15.minutes
    )
    
    # Send notifications if needed
    send_health_check_notifications(results)
    
    Rails.logger.info "Health check completed: #{results[:healthy_count]} healthy, #{results[:unhealthy_count]} unhealthy, #{results[:error_count]} errors"
  end
  
  def log_health_check_result(provider, is_healthy, response_time, error_message = nil)
    AiUsageLog.create!(
      account: provider.account,
      ai_provider: provider,
      operation_type: 'health_check',
      success: is_healthy,
      response_time_ms: response_time,
      error_message: error_message,
      metadata: {
        provider_type: provider.provider_type,
        health_status: is_healthy ? 'healthy' : 'unhealthy',
        check_timestamp: Time.current.iso8601
      }
    )
  end
  
  def handle_unhealthy_provider(provider, error = nil)
    # Update provider metadata
    metadata = provider.metadata || {}
    metadata['consecutive_failures'] = (metadata['consecutive_failures'] || 0) + 1
    metadata['last_failure_time'] = Time.current.iso8601
    metadata['last_failure_reason'] = error&.message || 'Health check failed'
    
    provider.update!(metadata: metadata)
    
    # If provider has failed multiple times, consider disabling it temporarily
    if metadata['consecutive_failures'] >= 3
      provider.update!(status: 'maintenance')
      
      Rails.logger.warn "Provider #{provider.name} disabled due to consecutive failures"
      
      # Notify administrators
      send_provider_failure_notification(provider, metadata['consecutive_failures'])
    end
    
    # Trigger failover logic if this is a primary provider
    if provider.primary?
      trigger_provider_failover(provider)
    end
  end
  
  def handle_healthy_provider(provider)
    # Reset failure count on successful health check
    metadata = provider.metadata || {}
    
    if metadata['consecutive_failures'].to_i > 0
      metadata['consecutive_failures'] = 0
      metadata['last_recovery_time'] = Time.current.iso8601
      provider.update!(metadata: metadata)
      
      # Re-enable provider if it was in maintenance
      if provider.status == 'maintenance'
        provider.update!(status: 'active')
        Rails.logger.info "Provider #{provider.name} re-enabled after recovery"
      end
    end
    
    # Update response time in metadata
    metadata['last_response_time'] = ((Time.current - provider.last_health_check) * 1000).round(2)
    provider.update!(metadata: metadata)
  end
  
  def trigger_provider_failover(failed_provider)
    account = failed_provider.account
    
    # Find next available provider
    fallback_provider = account.ai_providers
                              .active
                              .where.not(id: failed_provider.id)
                              .where(health_status: 'healthy')
                              .order(:priority)
                              .first
    
    if fallback_provider
      # Promote fallback provider temporarily
      fallback_provider.update!(priority: 'primary')
      failed_provider.update!(priority: 'fallback')
      
      Rails.logger.info "Failover triggered: #{fallback_provider.name} promoted to primary for account #{account.id}"
      
      # Log the failover event
      AiUsageLog.create!(
        account: account,
        ai_provider: failed_provider,
        operation_type: 'provider_failover',
        success: true,
        metadata: {
          failed_provider: failed_provider.name,
          new_primary_provider: fallback_provider.name,
          failover_timestamp: Time.current.iso8601
        }
      )
    else
      Rails.logger.error "No healthy fallback provider available for account #{account.id}"
      
      # Send critical alert
      send_critical_provider_alert(account, failed_provider)
    end
  end
  
  def send_health_check_notifications(results)
    # Send notifications only if there are significant issues
    if results[:unhealthy_count] > 0 || results[:error_count] > 0
      # This would integrate with your notification system
      Rails.logger.warn "Health check alert: #{results[:unhealthy_count]} unhealthy, #{results[:error_count]} error providers"
      
      # You could send emails, Slack notifications, etc. here
      # NotificationService.send_provider_health_alert(results)
    end
  end
  
  def send_provider_failure_notification(provider, failure_count)
    Rails.logger.error "Provider failure notification: #{provider.name} has failed #{failure_count} consecutive times"
    
    # Integrate with your notification system
    # NotificationService.send_provider_failure_alert(provider, failure_count)
  end
  
  def send_critical_provider_alert(account, failed_provider)
    Rails.logger.error "CRITICAL: No healthy providers available for account #{account.id} after #{failed_provider.name} failure"
    
    # Send immediate critical alert
    # NotificationService.send_critical_provider_alert(account, failed_provider)
  end
end