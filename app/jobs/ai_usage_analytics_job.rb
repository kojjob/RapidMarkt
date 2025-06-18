class AiUsageAnalyticsJob < ApplicationJob
  queue_as :ai_analytics
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(account_id = nil, period = '1.day')
    if account_id
      process_account_analytics(account_id, period)
    else
      process_global_analytics(period)
    end
  end
  
  private
  
  def process_account_analytics(account_id, period)
    account = Account.find(account_id)
    time_range = parse_period(period)
    
    usage_logs = account.ai_usage_logs.where(created_at: time_range)
    
    return if usage_logs.empty?
    
    analytics_data = calculate_analytics(usage_logs, account)
    
    # Store analytics in cache for quick access
    Rails.cache.write(
      "ai_analytics:account:#{account_id}:#{period}",
      analytics_data,
      expires_in: cache_expiry_for_period(period)
    )
    
    # Update account's AI usage summary
    update_account_usage_summary(account, analytics_data)
    
    # Generate cost optimization recommendations if needed
    if analytics_data[:total_cost] > account.subscription&.ai_budget_limit.to_f
      AiCostOptimizationJob.perform_later(account_id)
    end
    
    Rails.logger.info "Processed AI analytics for account #{account_id}: #{analytics_data[:total_requests]} requests, $#{analytics_data[:total_cost]}"
  end
  
  def process_global_analytics(period)
    time_range = parse_period(period)
    
    usage_logs = AiUsageLog.where(created_at: time_range)
    
    return if usage_logs.empty?
    
    # Global analytics
    global_analytics = {
      total_requests: usage_logs.count,
      total_tokens: usage_logs.sum(:tokens_used),
      total_cost: usage_logs.sum(:cost),
      success_rate: (usage_logs.where(success: true).count.to_f / usage_logs.count * 100).round(2),
      average_response_time: usage_logs.where.not(response_time_ms: nil).average(:response_time_ms)&.round(2),
      
      # Provider breakdown
      provider_stats: usage_logs.joins(:ai_provider)
                                .group('ai_providers.name')
                                .group('ai_providers.provider_type')
                                .calculate(:count),
      
      # Operation type breakdown
      operation_stats: usage_logs.group(:operation_type).calculate(:count),
      
      # Hourly distribution
      hourly_distribution: usage_logs.group_by_hour(:created_at, time_zone: 'UTC').count,
      
      # Top accounts by usage
      top_accounts: usage_logs.joins(:account)
                              .group('accounts.id', 'accounts.name')
                              .order('COUNT(*) DESC')
                              .limit(10)
                              .calculate(:count)
    }
    
    # Store global analytics
    Rails.cache.write(
      "ai_analytics:global:#{period}",
      global_analytics,
      expires_in: cache_expiry_for_period(period)
    )
    
    # Update provider performance metrics
    update_provider_performance_metrics(usage_logs)
    
    Rails.logger.info "Processed global AI analytics: #{global_analytics[:total_requests]} requests, $#{global_analytics[:total_cost]}"
  end
  
  def calculate_analytics(usage_logs, account)
    {
      total_requests: usage_logs.count,
      successful_requests: usage_logs.where(success: true).count,
      failed_requests: usage_logs.where(success: false).count,
      success_rate: (usage_logs.where(success: true).count.to_f / usage_logs.count * 100).round(2),
      
      total_tokens: usage_logs.sum(:tokens_used),
      average_tokens_per_request: usage_logs.average(:tokens_used)&.round(2),
      
      total_cost: usage_logs.sum(:cost),
      average_cost_per_request: usage_logs.average(:cost)&.round(4),
      
      average_response_time: usage_logs.where.not(response_time_ms: nil).average(:response_time_ms)&.round(2),
      
      # Provider breakdown
      provider_usage: usage_logs.joins(:ai_provider)
                                .group('ai_providers.name')
                                .calculate(:count),
      
      provider_costs: usage_logs.joins(:ai_provider)
                                .group('ai_providers.name')
                                .sum(:cost),
      
      # Operation type breakdown
      operation_breakdown: usage_logs.group(:operation_type).calculate(:count),
      operation_costs: usage_logs.group(:operation_type).sum(:cost),
      
      # Time-based analytics
      daily_usage: usage_logs.group_by_day(:created_at, time_zone: account.time_zone || 'UTC').count,
      hourly_usage: usage_logs.group_by_hour(:created_at, time_zone: account.time_zone || 'UTC').count,
      
      # Error analysis
      error_types: usage_logs.where(success: false)
                            .where.not(error_message: nil)
                            .group(:error_message)
                            .count,
      
      # Cost efficiency metrics
      cost_per_token: usage_logs.sum(:cost) / [usage_logs.sum(:tokens_used), 1].max,
      tokens_per_dollar: [usage_logs.sum(:tokens_used), 1].max / [usage_logs.sum(:cost), 0.01].max
    }
  end
  
  def update_account_usage_summary(account, analytics_data)
    # Update or create usage summary record
    summary = account.ai_usage_summary || account.build_ai_usage_summary
    
    summary.update!(
      total_requests: analytics_data[:total_requests],
      total_tokens: analytics_data[:total_tokens],
      total_cost: analytics_data[:total_cost],
      success_rate: analytics_data[:success_rate],
      average_response_time: analytics_data[:average_response_time],
      last_updated: Time.current,
      metadata: {
        provider_usage: analytics_data[:provider_usage],
        operation_breakdown: analytics_data[:operation_breakdown],
        cost_efficiency: {
          cost_per_token: analytics_data[:cost_per_token],
          tokens_per_dollar: analytics_data[:tokens_per_dollar]
        }
      }
    )
  rescue ActiveRecord::RecordNotFound
    # Handle case where ai_usage_summary association doesn't exist
    Rails.logger.warn "Could not update usage summary for account #{account.id} - association may not exist"
  end
  
  def update_provider_performance_metrics(usage_logs)
    provider_metrics = usage_logs.joins(:ai_provider)
                                 .group('ai_providers.id')
                                 .calculate(:average, :response_time_ms)
    
    provider_metrics.each do |provider_id, avg_response_time|
      provider = AiProvider.find_by(id: provider_id)
      next unless provider
      
      provider_logs = usage_logs.where(ai_provider: provider)
      
      performance_data = {
        average_response_time: avg_response_time&.round(2),
        success_rate: (provider_logs.where(success: true).count.to_f / provider_logs.count * 100).round(2),
        total_requests: provider_logs.count,
        total_cost: provider_logs.sum(:cost),
        last_updated: Time.current
      }
      
      # Store in provider's metadata or separate performance table
      provider.update(
        metadata: (provider.metadata || {}).merge(performance_metrics: performance_data)
      )
    end
  end
  
  def parse_period(period)
    case period
    when '1.hour'
      1.hour.ago..Time.current
    when '1.day'
      1.day.ago..Time.current
    when '1.week'
      1.week.ago..Time.current
    when '1.month'
      1.month.ago..Time.current
    else
      1.day.ago..Time.current
    end
  end
  
  def cache_expiry_for_period(period)
    case period
    when '1.hour'
      10.minutes
    when '1.day'
      1.hour
    when '1.week'
      4.hours
    when '1.month'
      12.hours
    else
      1.hour
    end
  end
end