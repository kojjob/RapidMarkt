# frozen_string_literal: true

class AiDashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :set_account
  before_action :initialize_ai_service

  # GET /ai_dashboard
  def index
    @dashboard_data = build_dashboard_data
    @ai_insights = fetch_ai_insights
    @provider_status = @ai_service.provider_health_check
    @usage_analytics = @ai_service.usage_analytics(1.day)
    @content_generations = recent_content_generations
    @performance_metrics = calculate_performance_metrics
  end

  # POST /ai_dashboard/generate_content
  def generate_content
    # Create content generation record
    content_generation = ContentGeneration.create!(
      account: current_account,
      prompt: params[:prompt],
      content_type: params[:content_type],
      status: 'pending',
      options: generation_options
    )

    # Queue background job
    AiContentGenerationJob.perform_async(
      content_generation.id,
      current_account.id
    )

    render json: {
      success: true,
      generation_id: content_generation.id,
      status: 'pending',
      message: 'Content generation started. You will be notified when complete.'
    }
  rescue => e
    render json: { success: false, error: 'Failed to start content generation' }, status: :internal_server_error
  end

  # POST /ai_dashboard/optimize_content
  def optimize_content
    # Create content generation record for optimization
    content_generation = ContentGeneration.create!(
      account: current_account,
      prompt: "Optimize: #{params[:content][0..100]}...",
      content_type: 'optimization',
      status: 'pending',
      options: {
        original_content: params[:content],
        optimization_type: params[:optimization_type],
        target_metrics: params[:target_metrics] || {}
      }
    )

    # Queue background job
    AiContentGenerationJob.perform_async(
      content_generation.id,
      current_account.id
    )

    render json: {
      success: true,
      generation_id: content_generation.id,
      status: 'pending',
      message: 'Content optimization started. You will be notified when complete.'
    }
  rescue => e
    render json: { success: false, error: 'Failed to start content optimization' }, status: :unprocessable_entity
  end

  # GET /ai_dashboard/insights
  def insights
    insight_type = params[:type] || 'performance_optimization'
    
    # Queue background job for insight generation
    job_id = AiInsightGenerationJob.perform_async(
      current_account.id,
      insight_type,
      build_insight_context(insight_type)
    )

    render json: {
      success: true,
      job_id: job_id,
      status: 'pending',
      message: 'Insight generation started. You will be notified when complete.'
    }
  rescue => e
    render json: { success: false, error: 'Failed to start insight generation' }, status: :unprocessable_entity
  end

  # GET /ai_dashboard/generation_status/:id
  def generation_status
    content_generation = ContentGeneration.find(params[:id])
    
    unless content_generation.account == current_account
      render json: { success: false, error: 'Unauthorized' }, status: :unauthorized
      return
    end

    render json: {
      success: true,
      generation: content_generation.as_json(
        include: [:ai_provider],
        methods: [:progress_percentage]
      )
    }
  rescue ActiveRecord::RecordNotFound
    render json: { success: false, error: 'Generation not found' }, status: :not_found
  end

  # POST /ai_dashboard/bulk_generate
  def bulk_generate
    prompts = params[:prompts] || []
    content_type = params[:content_type]
    
    if prompts.empty?
      render json: { success: false, error: 'No prompts provided' }, status: :bad_request
      return
    end

    # Create content generation records
    content_generations = prompts.map do |prompt|
      ContentGeneration.create!(
        account: current_account,
        prompt: prompt,
        content_type: content_type,
        status: 'pending',
        options: generation_options
      )
    end

    # Queue bulk generation job
    job_id = AiBulkContentGenerationJob.perform_async(
      content_generations.map(&:id),
      current_account.id
    )

    render json: {
      success: true,
      job_id: job_id,
      generation_ids: content_generations.map(&:id),
      status: 'pending',
      message: "Bulk generation started for #{prompts.length} items."
    }
  rescue => e
    render json: { success: false, error: 'Failed to start bulk generation' }, status: :internal_server_error
  end

  # GET /ai_dashboard/analytics
  def analytics
    period = parse_period(params[:period] || '1d')
    
    analytics_data = {
      usage: @ai_service.usage_analytics(period),
      content_performance: ContentGeneration.performance_summary(period),
      provider_comparison: provider_comparison_data(period),
      cost_breakdown: cost_breakdown_data(period),
      insights_summary: insights_summary_data(period)
    }

    render json: analytics_data
  end

  # GET /ai_dashboard/providers
  def providers
    providers_data = @account.ai_providers.includes(:ai_usage_logs).map do |provider|
      {
        id: provider.id,
        name: provider.name,
        provider_type: provider.provider_type,
        status: provider.status,
        health_status: provider.health_status,
        priority: provider.priority,
        capabilities: provider.capabilities,
        rate_limit_status: provider.within_rate_limit? ? 'ok' : 'exceeded',
        usage_stats: provider.usage_stats(1.day),
        last_health_check: provider.last_health_check,
        available_models: provider.available_models
      }
    end

    render json: { providers: providers_data }
  end

  # POST /ai_dashboard/providers/:id/health_check
  def provider_health_check
    provider = @account.ai_providers.find(params[:id])
    health_status = provider.health_check
    
    render json: {
      success: true,
      provider_id: provider.id,
      health_status: provider.health_status,
      last_check: provider.last_health_check
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
  end

  # GET /ai_dashboard/content_generations
  def content_generations
    generations = @account.content_generations
      .includes(:ai_provider, :user)
      .order(created_at: :desc)
      .limit(params[:limit] || 20)

    if params[:content_type].present?
      generations = generations.where(content_type: params[:content_type])
    end

    if params[:status].present?
      generations = generations.where(status: params[:status])
    end

    render json: {
      generations: generations.map do |gen|
        {
          id: gen.id,
          content_type: gen.content_type,
          prompt: gen.prompt.truncate(100),
          generated_content: gen.generated_content.truncate(200),
          status: gen.status,
          quality_score: gen.quality_score,
          performance_score: gen.performance_score,
          provider_name: gen.ai_provider.name,
          user_name: gen.user.name,
          created_at: gen.created_at,
          tokens_used: gen.tokens_used,
          generation_cost: gen.generation_cost
        }
      end
    }
  end

  # POST /ai_dashboard/content_generations/:id/approve
  def approve_content
    generation = @account.content_generations.find(params[:id])
    generation.approve!
    
    render json: { success: true, status: generation.status }
  end

  # POST /ai_dashboard/content_generations/:id/reject
  def reject_content
    generation = @account.content_generations.find(params[:id])
    generation.reject!(params[:reason])
    
    render json: { success: true, status: generation.status }
  end

  # GET /ai_dashboard/real_time_metrics
  def real_time_metrics
    metrics = {
      active_generations: active_generations_count,
      queue_status: generation_queue_status,
      provider_status: @ai_service.provider_health_check,
      recent_activity: recent_activity_feed,
      cost_today: daily_cost_summary,
      performance_alerts: performance_alerts
    }

    render json: metrics
  end

  # POST /ai_dashboard/bulk_generate
  def bulk_generate
    prompts = params[:prompts] || []
    content_type = params[:content_type]
    options = generation_options

    results = []
    errors = []

    prompts.each_with_index do |prompt, index|
      begin
        result = @ai_service.generate_content(
          prompt: prompt,
          content_type: content_type,
          options: options
        )
        results << result.merge(index: index)
      rescue => e
        errors << { index: index, error: e.message }
      end
    end

    render json: {
      success: true,
      results: results,
      errors: errors,
      total_processed: prompts.length
    }
  end

  private

  def set_account
    @account = current_user.account
  end

  def initialize_ai_service
    @ai_service = AiService.new(@account)
  end

  def build_dashboard_data
    {
      total_campaigns: @account.campaigns.count,
      total_contacts: @account.contacts.count,
      total_templates: @account.templates.count,
      ai_generations_today: @account.content_generations.where(created_at: Date.current.all_day).count,
      ai_cost_today: @account.ai_usage_logs.where(created_at: Date.current.all_day).sum(:cost),
      active_providers: @account.ai_providers.active.count,
      recent_campaigns: @account.campaigns.includes(:template).order(created_at: :desc).limit(5),
      top_performing_content: top_performing_content
    }
  end

  def fetch_ai_insights
    AiInsight.generate_dashboard_insights(@account, 5)
  end

  def recent_content_generations
    @account.content_generations
      .includes(:ai_provider, :user)
      .order(created_at: :desc)
      .limit(10)
  end

  def calculate_performance_metrics
    period = 7.days
    
    {
      content_approval_rate: content_approval_rate(period),
      average_quality_score: average_quality_score(period),
      cost_per_generation: cost_per_generation(period),
      provider_efficiency: provider_efficiency_metrics(period)
    }
  end

  def generation_options
    {
      model: params[:model],
      max_tokens: params[:max_tokens]&.to_i || 500,
      temperature: params[:temperature]&.to_f || 0.7,
      prefer_speed: params[:prefer_speed] == 'true',
      prefer_cost: params[:prefer_cost] == 'true'
    }.compact
  end

  def build_insight_context(insight_type)
    case insight_type
    when 'performance_optimization'
      {
        recent_campaigns: @account.campaigns.recent(1.month).with_stats,
        content_performance: @account.content_generations.recent(1.month).performance_summary
      }
    when 'content_suggestion'
      {
        top_content: @account.content_generations.high_quality.recent(3.months),
        audience_segments: @account.contacts.group(:segment).count
      }
    when 'audience_analysis'
      {
        contact_engagement: @account.contacts.engagement_summary,
        campaign_performance: @account.campaigns.performance_by_segment
      }
    else
      {}
    end
  end

  def parse_period(period_string)
    case period_string
    when '1h' then 1.hour
    when '1d' then 1.day
    when '1w' then 1.week
    when '1m' then 1.month
    else 1.day
    end
  end

  def provider_comparison_data(period)
    @account.ai_usage_logs
      .joins(:ai_provider)
      .where(created_at: period.ago..Time.current)
      .group('ai_providers.name')
      .group('ai_providers.provider_type')
      .select(
        'ai_providers.name',
        'ai_providers.provider_type',
        'COUNT(*) as request_count',
        'AVG(response_time_ms) as avg_response_time',
        'SUM(cost) as total_cost',
        'SUM(CASE WHEN success THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as success_rate'
      )
  end

  def cost_breakdown_data(period)
    {
      by_operation: @account.ai_usage_logs.where(created_at: period.ago..Time.current)
        .group(:operation_type).sum(:cost),
      by_provider: @account.ai_usage_logs.joins(:ai_provider)
        .where(created_at: period.ago..Time.current)
        .group('ai_providers.name').sum(:cost),
      daily_trend: @account.ai_usage_logs.where(created_at: period.ago..Time.current)
        .group_by_day(:created_at).sum(:cost)
    }
  end

  def insights_summary_data(period)
    insights = @account.ai_insights.where(created_at: period.ago..Time.current)
    
    {
      total_insights: insights.count,
      by_type: insights.group(:insight_type).count,
      by_priority: insights.group(:priority).count,
      implemented_count: insights.where(status: 'implemented').count,
      average_confidence: insights.average(:confidence_score)&.round(2)
    }
  end

  def active_generations_count
    # Count of currently processing generations (if using background jobs)
    0 # Placeholder
  end

  def generation_queue_status
    {
      pending: 0,
      processing: 0,
      completed_today: @account.content_generations.where(created_at: Date.current.all_day).count
    }
  end

  def recent_activity_feed
    activities = []
    
    # Recent content generations
    @account.content_generations.recent(1.hour).limit(5).each do |gen|
      activities << {
        type: 'content_generated',
        message: "#{gen.content_type.humanize} generated",
        timestamp: gen.created_at,
        metadata: { provider: gen.ai_provider.name, quality: gen.quality_score }
      }
    end
    
    # Recent insights
    @account.ai_insights.recent(1.hour).limit(3).each do |insight|
      activities << {
        type: 'insight_generated',
        message: insight.title,
        timestamp: insight.created_at,
        metadata: { type: insight.insight_type, confidence: insight.confidence_score }
      }
    end
    
    activities.sort_by { |a| a[:timestamp] }.reverse.first(10)
  end

  def daily_cost_summary
    today_logs = @account.ai_usage_logs.where(created_at: Date.current.all_day)
    
    {
      total: today_logs.sum(:cost),
      by_provider: today_logs.joins(:ai_provider).group('ai_providers.name').sum(:cost),
      requests: today_logs.count,
      tokens: today_logs.sum(:tokens_used)
    }
  end

  def performance_alerts
    alerts = []
    
    # Check for high error rates
    recent_logs = @account.ai_usage_logs.where(created_at: 1.hour.ago..Time.current)
    if recent_logs.any?
      error_rate = (recent_logs.where(success: false).count.to_f / recent_logs.count * 100)
      if error_rate > 10
        alerts << {
          type: 'high_error_rate',
          message: "High error rate detected: #{error_rate.round(1)}%",
          severity: 'warning'
        }
      end
    end
    
    # Check for rate limit issues
    @account.ai_providers.active.each do |provider|
      unless provider.within_rate_limit?
        alerts << {
          type: 'rate_limit_exceeded',
          message: "Rate limit exceeded for #{provider.name}",
          severity: 'error'
        }
      end
    end
    
    alerts
  end

  def top_performing_content
    @account.content_generations
      .where('performance_score > ?', 80)
      .order(performance_score: :desc)
      .limit(5)
  end

  def content_approval_rate(period)
    generations = @account.content_generations.where(created_at: period.ago..Time.current)
    return 0 if generations.count.zero?
    
    (generations.approved.count.to_f / generations.count * 100).round(2)
  end

  def average_quality_score(period)
    @account.content_generations
      .where(created_at: period.ago..Time.current)
      .average(:quality_score)&.round(2) || 0
  end

  def cost_per_generation(period)
    generations = @account.content_generations.where(created_at: period.ago..Time.current)
    return 0 if generations.count.zero?
    
    total_cost = @account.ai_usage_logs
      .where(created_at: period.ago..Time.current)
      .sum(:cost)
    
    (total_cost / generations.count).round(4)
  end

  def provider_efficiency_metrics(period)
    @account.ai_providers.active.map do |provider|
      logs = provider.ai_usage_logs.where(created_at: period.ago..Time.current)
      next unless logs.any?
      
      {
        provider: provider.name,
        avg_response_time: logs.average(:response_time_ms)&.round(2),
        success_rate: (logs.successful.count.to_f / logs.count * 100).round(2),
        cost_efficiency: (logs.sum(:tokens_used).to_f / logs.sum(:cost)).round(2)
      }
    end.compact
  end
end