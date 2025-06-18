class AiCostOptimizationJob < ApplicationJob
  queue_as :ai_optimization
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(account_id, optimization_type = 'full')
    account = Account.find(account_id)
    
    Rails.logger.info "Starting cost optimization for account #{account_id} (#{optimization_type})"
    
    case optimization_type
    when 'provider_selection'
      optimize_provider_selection(account)
    when 'usage_patterns'
      analyze_usage_patterns(account)
    when 'budget_monitoring'
      monitor_budget_usage(account)
    when 'model_recommendations'
      recommend_model_optimizations(account)
    else
      perform_full_optimization(account)
    end
  end
  
  private
  
  def perform_full_optimization(account)
    optimization_results = {
      account_id: account.id,
      optimization_timestamp: Time.current,
      recommendations: [],
      potential_savings: 0.0,
      current_monthly_cost: calculate_monthly_cost(account)
    }
    
    # Run all optimization analyses
    optimization_results[:recommendations].concat(optimize_provider_selection(account))
    optimization_results[:recommendations].concat(analyze_usage_patterns(account))
    optimization_results[:recommendations].concat(recommend_model_optimizations(account))
    
    # Calculate total potential savings
    optimization_results[:potential_savings] = optimization_results[:recommendations]
                                                .sum { |rec| rec[:potential_savings] || 0.0 }
    
    # Store optimization results
    store_optimization_results(account, optimization_results)
    
    # Send recommendations if significant savings are possible
    if optimization_results[:potential_savings] > 10.0 # $10+ potential savings
      send_optimization_recommendations(account, optimization_results)
    end
    
    # Monitor budget if approaching limits
    monitor_budget_usage(account)
    
    Rails.logger.info "Cost optimization completed for account #{account_id}: $#{optimization_results[:potential_savings].round(2)} potential savings"
    
    optimization_results
  end
  
  def optimize_provider_selection(account)
    recommendations = []
    
    # Analyze provider costs and performance
    provider_analysis = analyze_provider_performance(account)
    
    provider_analysis.each do |provider_id, analysis|
      provider = AiProvider.find(provider_id)
      
      # Check if provider is cost-inefficient
      if analysis[:cost_per_token] > analysis[:average_cost_per_token] * 1.5
        recommendations << {
          type: 'provider_optimization',
          priority: 'high',
          title: "High cost provider: #{provider.name}",
          description: "Provider #{provider.name} costs #{(analysis[:cost_per_token] * 1000).round(4)}¢ per 1K tokens, which is #{((analysis[:cost_per_token] / analysis[:average_cost_per_token] - 1) * 100).round(1)}% above average.",
          recommendation: "Consider switching to a more cost-effective provider or negotiating better rates.",
          potential_savings: analysis[:potential_monthly_savings],
          provider_id: provider_id,
          current_cost: analysis[:monthly_cost],
          suggested_action: 'switch_provider'
        }
      end
      
      # Check for underutilized providers
      if analysis[:usage_percentage] < 10 && analysis[:monthly_cost] > 5.0
        recommendations << {
          type: 'provider_consolidation',
          priority: 'medium',
          title: "Underutilized provider: #{provider.name}",
          description: "Provider #{provider.name} is only used #{analysis[:usage_percentage].round(1)}% of the time but costs $#{analysis[:monthly_cost].round(2)}/month.",
          recommendation: "Consider consolidating usage to primary providers or removing this provider.",
          potential_savings: analysis[:monthly_cost] * 0.8,
          provider_id: provider_id,
          suggested_action: 'consolidate_or_remove'
        }
      end
    end
    
    recommendations
  end
  
  def analyze_usage_patterns(account)
    recommendations = []
    
    # Analyze usage over the last 30 days
    usage_logs = account.ai_usage_logs.where(created_at: 30.days.ago..Time.current)
    
    return recommendations if usage_logs.empty?
    
    # Analyze peak usage times
    hourly_usage = usage_logs.group_by_hour(:created_at, time_zone: account.time_zone || 'UTC').count
    peak_hours = hourly_usage.sort_by { |_, count| -count }.first(3).map(&:first)
    
    # Analyze operation types
    operation_costs = usage_logs.group(:operation_type).sum(:cost)
    total_cost = operation_costs.values.sum
    
    operation_costs.each do |operation_type, cost|
      cost_percentage = (cost / total_cost * 100).round(1)
      
      if cost_percentage > 40 # If one operation type dominates costs
        case operation_type
        when 'content_generation'
          recommendations << {
            type: 'usage_optimization',
            priority: 'medium',
            title: "High content generation costs",
            description: "Content generation accounts for #{cost_percentage}% of AI costs ($#{cost.round(2)}/month).",
            recommendation: "Consider using templates, batch processing, or lower-cost models for routine content generation.",
            potential_savings: cost * 0.3,
            operation_type: operation_type,
            suggested_action: 'optimize_content_generation'
          }
        when 'insight_generation'
          recommendations << {
            type: 'usage_optimization',
            priority: 'low',
            title: "Frequent insight generation",
            description: "Insight generation accounts for #{cost_percentage}% of AI costs ($#{cost.round(2)}/month).",
            recommendation: "Consider reducing insight generation frequency or caching results longer.",
            potential_savings: cost * 0.2,
            operation_type: operation_type,
            suggested_action: 'reduce_insight_frequency'
          }
        end
      end
    end
    
    # Check for inefficient token usage
    avg_tokens_per_request = usage_logs.average(:tokens_used)
    if avg_tokens_per_request && avg_tokens_per_request > 1000
      recommendations << {
        type: 'token_optimization',
        priority: 'medium',
        title: "High token usage per request",
        description: "Average token usage is #{avg_tokens_per_request.round(0)} tokens per request, which may indicate inefficient prompts.",
        recommendation: "Review and optimize prompts to reduce token usage. Consider using more specific, concise prompts.",
        potential_savings: total_cost * 0.25,
        suggested_action: 'optimize_prompts'
      }
    end
    
    recommendations
  end
  
  def recommend_model_optimizations(account)
    recommendations = []
    
    # Analyze model usage and costs
    model_usage = account.ai_usage_logs
                        .joins(:ai_provider)
                        .where(created_at: 30.days.ago..Time.current)
                        .group('ai_providers.provider_type')
                        .group("metadata->>'model'")
                        .calculate(:sum, :cost)
    
    model_usage.each do |(provider_type, model), cost|
      next unless model && cost > 5.0 # Only analyze models with significant cost
      
      # Suggest model downgrades for specific use cases
      case provider_type
      when 'openai'
        if model == 'gpt-4' && cost > 20.0
          recommendations << {
            type: 'model_optimization',
            priority: 'high',
            title: "Consider GPT-3.5 for routine tasks",
            description: "GPT-4 usage costs $#{cost.round(2)}/month. Many tasks could use GPT-3.5 at ~10x lower cost.",
            recommendation: "Evaluate if GPT-3.5 Turbo can handle routine content generation and simple analysis tasks.",
            potential_savings: cost * 0.7,
            provider_type: provider_type,
            current_model: model,
            suggested_model: 'gpt-3.5-turbo',
            suggested_action: 'downgrade_model'
          }
        end
      when 'anthropic'
        if model == 'claude-3-opus' && cost > 15.0
          recommendations << {
            type: 'model_optimization',
            priority: 'medium',
            title: "Consider Claude Sonnet for routine tasks",
            description: "Claude Opus usage costs $#{cost.round(2)}/month. Claude Sonnet offers good performance at lower cost.",
            recommendation: "Test Claude Sonnet for content generation and analysis tasks that don't require Opus-level capabilities.",
            potential_savings: cost * 0.5,
            provider_type: provider_type,
            current_model: model,
            suggested_model: 'claude-3-sonnet',
            suggested_action: 'downgrade_model'
          }
        end
      end
    end
    
    recommendations
  end
  
  def monitor_budget_usage(account)
    return unless account.subscription&.ai_budget_limit
    
    current_month_cost = calculate_monthly_cost(account)
    budget_limit = account.subscription.ai_budget_limit.to_f
    usage_percentage = (current_month_cost / budget_limit * 100).round(1)
    
    if usage_percentage >= 90
      send_budget_alert(account, current_month_cost, budget_limit, 'critical')
    elsif usage_percentage >= 75
      send_budget_alert(account, current_month_cost, budget_limit, 'warning')
    end
    
    # Project end-of-month usage
    days_in_month = Time.current.end_of_month.day
    current_day = Time.current.day
    projected_cost = (current_month_cost / current_day) * days_in_month
    
    if projected_cost > budget_limit * 1.1 # Projected to exceed by 10%
      send_budget_projection_alert(account, projected_cost, budget_limit)
    end
  end
  
  def analyze_provider_performance(account)
    providers = account.ai_providers.includes(:ai_usage_logs)
    analysis = {}
    
    total_cost = account.ai_usage_logs.where(created_at: 30.days.ago..Time.current).sum(:cost)
    total_tokens = account.ai_usage_logs.where(created_at: 30.days.ago..Time.current).sum(:tokens_used)
    average_cost_per_token = total_tokens > 0 ? total_cost / total_tokens : 0
    
    providers.each do |provider|
      logs = provider.ai_usage_logs.where(created_at: 30.days.ago..Time.current)
      next if logs.empty?
      
      provider_cost = logs.sum(:cost)
      provider_tokens = logs.sum(:tokens_used)
      cost_per_token = provider_tokens > 0 ? provider_cost / provider_tokens : 0
      
      analysis[provider.id] = {
        monthly_cost: provider_cost,
        tokens_used: provider_tokens,
        cost_per_token: cost_per_token,
        average_cost_per_token: average_cost_per_token,
        usage_percentage: total_cost > 0 ? (provider_cost / total_cost * 100) : 0,
        request_count: logs.count,
        success_rate: logs.where(success: true).count.to_f / logs.count * 100,
        potential_monthly_savings: cost_per_token > average_cost_per_token ? 
          (cost_per_token - average_cost_per_token) * provider_tokens : 0
      }
    end
    
    analysis
  end
  
  def calculate_monthly_cost(account)
    account.ai_usage_logs
          .where(created_at: Time.current.beginning_of_month..Time.current)
          .sum(:cost)
  end
  
  def store_optimization_results(account, results)
    Rails.cache.write(
      "ai_optimization:account:#{account.id}",
      results,
      expires_in: 24.hours
    )
    
    # Also store in database if you have an optimization_results table
    # OptimizationResult.create!(
    #   account: account,
    #   optimization_type: 'full',
    #   results: results,
    #   potential_savings: results[:potential_savings]
    # )
  end
  
  def send_optimization_recommendations(account, results)
    Rails.logger.info "Sending optimization recommendations to account #{account.id}: $#{results[:potential_savings].round(2)} potential savings"
    
    # Integrate with your notification system
    # NotificationService.send_cost_optimization_recommendations(account, results)
  end
  
  def send_budget_alert(account, current_cost, budget_limit, severity)
    usage_percentage = (current_cost / budget_limit * 100).round(1)
    
    Rails.logger.warn "Budget alert (#{severity}) for account #{account.id}: #{usage_percentage}% of budget used ($#{current_cost.round(2)}/$#{budget_limit})"
    
    # Integrate with your notification system
    # NotificationService.send_budget_alert(account, current_cost, budget_limit, severity)
  end
  
  def send_budget_projection_alert(account, projected_cost, budget_limit)
    Rails.logger.warn "Budget projection alert for account #{account.id}: Projected to spend $#{projected_cost.round(2)} vs budget of $#{budget_limit}"
    
    # Integrate with your notification system
    # NotificationService.send_budget_projection_alert(account, projected_cost, budget_limit)
  end
end