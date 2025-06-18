# frozen_string_literal: true

class AiService
  include HTTParty
  
  class ProviderError < StandardError; end
  class RateLimitError < StandardError; end
  class QuotaExceededError < StandardError; end
  class InvalidResponseError < StandardError; end

  def initialize(account)
    @account = account
    @providers = account.ai_providers.active.order(:priority)
  end

  # Main method for generating content with automatic provider fallback
  def generate_content(prompt:, content_type:, options: {})
    validate_inputs(prompt, content_type)
    
    provider = select_optimal_provider(content_type, options)
    raise ProviderError, "No suitable AI provider available" unless provider

    attempt_generation(provider, prompt, content_type, options)
  rescue => e
    handle_generation_error(e, prompt, content_type, options)
  end

  # Generate insights for the dashboard
  def generate_insights(insight_type:, context: {})
    provider = select_provider_for_capability('analysis')
    raise ProviderError, "No provider available for insights generation" unless provider

    prompt = build_insight_prompt(insight_type, context)
    
    response = call_provider_api(
      provider: provider,
      prompt: prompt,
      operation_type: 'analysis',
      options: { max_tokens: 500, temperature: 0.3 }
    )

    parse_insight_response(response, insight_type)
  end

  # Optimize existing content
  def optimize_content(content:, optimization_type:, target_metrics: {})
    provider = select_provider_for_capability('text_generation')
    raise ProviderError, "No provider available for content optimization" unless provider

    prompt = build_optimization_prompt(content, optimization_type, target_metrics)
    
    response = call_provider_api(
      provider: provider,
      prompt: prompt,
      operation_type: 'content_optimization',
      options: { max_tokens: 1000, temperature: 0.5 }
    )

    parse_optimization_response(response)
  end

  # Analyze content performance and provide recommendations
  def analyze_performance(content_id:, metrics:)
    provider = select_provider_for_capability('analysis')
    return {} unless provider

    content = ContentGeneration.find(content_id)
    prompt = build_performance_analysis_prompt(content, metrics)
    
    response = call_provider_api(
      provider: provider,
      prompt: prompt,
      operation_type: 'analysis',
      options: { max_tokens: 300, temperature: 0.2 }
    )

    parse_performance_analysis(response)
  end

  # Get provider health status
  def provider_health_check
    results = {}
    
    @providers.each do |provider|
      results[provider.name] = {
        status: provider.health_check ? 'healthy' : 'unhealthy',
        last_check: provider.last_health_check,
        rate_limit_status: provider.within_rate_limit? ? 'ok' : 'exceeded',
        usage_stats: provider.usage_stats(1.hour)
      }
    end
    
    results
  end

  # Get cost and usage analytics
  def usage_analytics(period = 1.day)
    logs = @account.ai_usage_logs.includes(:ai_provider).where(created_at: period.ago..Time.current)
    
    {
      total_requests: logs.count,
      total_cost: logs.sum(:cost),
      total_tokens: logs.sum(:tokens_used),
      average_response_time: logs.average(:response_time_ms)&.round(2),
      success_rate: (logs.successful.count.to_f / logs.count * 100).round(2),
      cost_by_provider: logs.group('ai_providers.name').sum(:cost),
      requests_by_operation: logs.group(:operation_type).count,
      hourly_usage: logs.group_by_hour(:created_at).count
    }
  end

  private

  def validate_inputs(prompt, content_type)
    raise ArgumentError, "Prompt cannot be blank" if prompt.blank?
    raise ArgumentError, "Invalid content type" unless ContentGeneration::CONTENT_CONFIGS.key?(content_type)
  end

  def select_optimal_provider(content_type, options)
    capability = map_content_type_to_capability(content_type)
    
    # Filter providers by capability and availability
    suitable_providers = @providers.select do |provider|
      provider.supports_capability?(capability) &&
      provider.within_rate_limit? &&
      provider.health_status == 'healthy'
    end

    return nil if suitable_providers.empty?

    # Select based on priority and performance
    if options[:prefer_speed]
      suitable_providers.min_by { |p| p.usage_stats(1.hour)[:average_response_time] || 1000 }
    elsif options[:prefer_cost]
      suitable_providers.min_by { |p| estimate_cost(p, options[:estimated_tokens] || 500) }
    else
      suitable_providers.first # Use priority order
    end
  end

  def select_provider_for_capability(capability)
    @providers.find { |p| p.supports_capability?(capability) && p.within_rate_limit? }
  end

  def attempt_generation(provider, prompt, content_type, options)
    start_time = Time.current
    
    response = call_provider_api(
      provider: provider,
      prompt: prompt,
      operation_type: map_content_type_to_capability(content_type),
      options: options
    )
    
    content_generation = create_content_generation_record(
      provider: provider,
      prompt: prompt,
      content_type: content_type,
      response: response,
      generation_time: (Time.current - start_time) * 1000
    )
    
    {
      content: response[:content],
      metadata: response[:metadata] || {},
      generation_id: content_generation.id,
      provider_used: provider.name,
      tokens_used: response[:tokens_used],
      cost: response[:cost]
    }
  end

  def call_provider_api(provider:, prompt:, operation_type:, options: {})
    case provider.provider_type
    when 'openai'
      call_openai_api(provider, prompt, operation_type, options)
    when 'anthropic'
      call_anthropic_api(provider, prompt, operation_type, options)
    when 'google'
      call_google_api(provider, prompt, operation_type, options)
    when 'cohere'
      call_cohere_api(provider, prompt, operation_type, options)
    else
      call_custom_api(provider, prompt, operation_type, options)
    end
  end

  def call_openai_api(provider, prompt, operation_type, options)
    model = options[:model] || 'gpt-3.5-turbo'
    max_tokens = options[:max_tokens] || 500
    temperature = options[:temperature] || 0.7
    
    headers = {
      'Authorization' => "Bearer #{provider.api_key}",
      'Content-Type' => 'application/json'
    }
    
    body = {
      model: model,
      messages: [{ role: 'user', content: prompt }],
      max_tokens: max_tokens,
      temperature: temperature
    }
    
    start_time = Time.current
    response = HTTParty.post(
      "#{provider.api_endpoint}/chat/completions",
      headers: headers,
      body: body.to_json,
      timeout: 30
    )
    response_time = (Time.current - start_time) * 1000
    
    handle_api_response(provider, response, response_time, operation_type)
  end

  def call_anthropic_api(provider, prompt, operation_type, options)
    model = options[:model] || 'claude-3-sonnet-20240229'
    max_tokens = options[:max_tokens] || 500
    temperature = options[:temperature] || 0.7
    
    headers = {
      'x-api-key' => provider.api_key,
      'Content-Type' => 'application/json',
      'anthropic-version' => '2023-06-01'
    }
    
    body = {
      model: model,
      max_tokens: max_tokens,
      temperature: temperature,
      messages: [{ role: 'user', content: prompt }]
    }
    
    start_time = Time.current
    response = HTTParty.post(
      "#{provider.api_endpoint}/messages",
      headers: headers,
      body: body.to_json,
      timeout: 30
    )
    response_time = (Time.current - start_time) * 1000
    
    handle_api_response(provider, response, response_time, operation_type)
  end

  def call_google_api(provider, prompt, operation_type, options)
    # Google Gemini API implementation
    model = options[:model] || 'gemini-pro'
    
    headers = {
      'Content-Type' => 'application/json'
    }
    
    body = {
      contents: [{
        parts: [{ text: prompt }]
      }],
      generationConfig: {
        maxOutputTokens: options[:max_tokens] || 500,
        temperature: options[:temperature] || 0.7
      }
    }
    
    start_time = Time.current
    response = HTTParty.post(
      "#{provider.api_endpoint}/v1/models/#{model}:generateContent?key=#{provider.api_key}",
      headers: headers,
      body: body.to_json,
      timeout: 30
    )
    response_time = (Time.current - start_time) * 1000
    
    handle_api_response(provider, response, response_time, operation_type)
  end

  def call_cohere_api(provider, prompt, operation_type, options)
    # Cohere API implementation
    model = options[:model] || 'command'
    
    headers = {
      'Authorization' => "Bearer #{provider.api_key}",
      'Content-Type' => 'application/json'
    }
    
    body = {
      model: model,
      prompt: prompt,
      max_tokens: options[:max_tokens] || 500,
      temperature: options[:temperature] || 0.7
    }
    
    start_time = Time.current
    response = HTTParty.post(
      "#{provider.api_endpoint}/generate",
      headers: headers,
      body: body.to_json,
      timeout: 30
    )
    response_time = (Time.current - start_time) * 1000
    
    handle_api_response(provider, response, response_time, operation_type)
  end

  def call_custom_api(provider, prompt, operation_type, options)
    # Generic implementation for custom providers
    raise NotImplementedError, "Custom provider implementation needed"
  end

  def handle_api_response(provider, response, response_time, operation_type)
    success = response.success?
    
    # Log the API usage
    log_usage(
      provider: provider,
      operation_type: operation_type,
      response_time: response_time,
      success: success,
      response_data: response.parsed_response
    )
    
    unless success
      handle_api_error(response)
    end
    
    parse_provider_response(provider.provider_type, response.parsed_response)
  end

  def handle_api_error(response)
    case response.code
    when 429
      raise RateLimitError, "Rate limit exceeded"
    when 402
      raise QuotaExceededError, "API quota exceeded"
    when 400..499
      raise ProviderError, "Client error: #{response.parsed_response}"
    when 500..599
      raise ProviderError, "Server error: #{response.code}"
    else
      raise ProviderError, "Unknown error: #{response.code}"
    end
  end

  def parse_provider_response(provider_type, response_data)
    case provider_type
    when 'openai'
      {
        content: response_data.dig('choices', 0, 'message', 'content'),
        tokens_used: response_data.dig('usage', 'total_tokens'),
        cost: calculate_openai_cost(response_data)
      }
    when 'anthropic'
      {
        content: response_data.dig('content', 0, 'text'),
        tokens_used: response_data.dig('usage', 'input_tokens').to_i + response_data.dig('usage', 'output_tokens').to_i,
        cost: calculate_anthropic_cost(response_data)
      }
    when 'google'
      {
        content: response_data.dig('candidates', 0, 'content', 'parts', 0, 'text'),
        tokens_used: response_data.dig('usageMetadata', 'totalTokenCount'),
        cost: calculate_google_cost(response_data)
      }
    when 'cohere'
      {
        content: response_data.dig('generations', 0, 'text'),
        tokens_used: response_data.dig('meta', 'billed_units', 'output_tokens'),
        cost: calculate_cohere_cost(response_data)
      }
    else
      { content: response_data.to_s, tokens_used: 0, cost: 0 }
    end
  end

  def calculate_openai_cost(response_data)
    # Implementation based on OpenAI pricing
    0.0 # Placeholder
  end

  def calculate_anthropic_cost(response_data)
    # Implementation based on Anthropic pricing
    0.0 # Placeholder
  end

  def calculate_google_cost(response_data)
    # Implementation based on Google pricing
    0.0 # Placeholder
  end

  def calculate_cohere_cost(response_data)
    # Implementation based on Cohere pricing
    0.0 # Placeholder
  end

  def log_usage(provider:, operation_type:, response_time:, success:, response_data:)
    tokens_used = extract_tokens_from_response(provider.provider_type, response_data)
    cost = calculate_cost(provider.provider_type, response_data)
    
    AiUsageLog.create!(
      ai_provider: provider,
      account: @account,
      user: Current.user,
      operation_type: operation_type,
      model_used: extract_model_from_response(provider.provider_type, response_data),
      tokens_used: tokens_used,
      response_time_ms: response_time,
      cost: cost,
      success: success,
      request_metadata: { response_code: response_data&.dig('code') },
      response_metadata: response_data
    )
  end

  def extract_tokens_from_response(provider_type, response_data)
    case provider_type
    when 'openai'
      response_data&.dig('usage', 'total_tokens') || 0
    when 'anthropic'
      (response_data&.dig('usage', 'input_tokens') || 0) + (response_data&.dig('usage', 'output_tokens') || 0)
    else
      0
    end
  end

  def extract_model_from_response(provider_type, response_data)
    case provider_type
    when 'openai'
      response_data&.dig('model') || 'unknown'
    when 'anthropic'
      response_data&.dig('model') || 'unknown'
    else
      'unknown'
    end
  end

  def calculate_cost(provider_type, response_data)
    # This would calculate actual cost based on provider pricing
    0.0
  end

  def map_content_type_to_capability(content_type)
    case content_type
    when 'email_subject', 'email_body', 'social_post', 'ad_copy'
      'text_generation'
    when 'blog_post', 'newsletter_content'
      'chat_completion'
    else
      'text_generation'
    end
  end

  def estimate_cost(provider, estimated_tokens)
    # Rough cost estimation for provider selection
    base_costs = {
      'openai' => 0.002,
      'anthropic' => 0.008,
      'google' => 0.0005,
      'cohere' => 0.001
    }
    
    (base_costs[provider.provider_type] || 0.001) * (estimated_tokens / 1000.0)
  end

  def create_content_generation_record(provider:, prompt:, content_type:, response:, generation_time:)
    ContentGeneration.create!(
      account: @account,
      ai_provider: provider,
      user: Current.user,
      content_type: content_type,
      prompt: prompt,
      generated_content: response[:content],
      status: 'draft',
      metadata: {
        generation_time_ms: generation_time,
        tokens_used: response[:tokens_used],
        cost: response[:cost],
        provider_metadata: response[:metadata] || {}
      }
    )
  end

  def handle_generation_error(error, prompt, content_type, options)
    case error
    when RateLimitError
      # Try with a different provider
      fallback_provider = find_fallback_provider(content_type)
      if fallback_provider
        attempt_generation(fallback_provider, prompt, content_type, options)
      else
        raise error
      end
    else
      raise error
    end
  end

  def find_fallback_provider(content_type)
    capability = map_content_type_to_capability(content_type)
    @providers.find { |p| p.supports_capability?(capability) && p.within_rate_limit? && p.priority == 'fallback' }
  end

  def build_insight_prompt(insight_type, context)
    # Build prompts for different insight types
    case insight_type
    when 'performance_optimization'
      "Analyze the following campaign performance data and provide optimization recommendations: #{context.to_json}"
    when 'content_suggestion'
      "Based on the following audience and campaign data, suggest content improvements: #{context.to_json}"
    else
      "Provide insights for #{insight_type} based on: #{context.to_json}"
    end
  end

  def build_optimization_prompt(content, optimization_type, target_metrics)
    "Optimize the following #{optimization_type} content to improve #{target_metrics.keys.join(', ')}: #{content}"
  end

  def build_performance_analysis_prompt(content, metrics)
    "Analyze the performance of this content and provide recommendations: Content: #{content.generated_content}\nMetrics: #{metrics.to_json}"
  end

  def parse_insight_response(response, insight_type)
    # Parse AI response into structured insight data
    {
      title: extract_title_from_response(response[:content]),
      content: response[:content],
      confidence_score: 75, # Default confidence
      metadata: { tokens_used: response[:tokens_used], cost: response[:cost] }
    }
  end

  def parse_optimization_response(response)
    {
      optimized_content: response[:content],
      improvements: extract_improvements_from_response(response[:content]),
      metadata: { tokens_used: response[:tokens_used], cost: response[:cost] }
    }
  end

  def parse_performance_analysis(response)
    {
      analysis: response[:content],
      recommendations: extract_recommendations_from_response(response[:content]),
      metadata: { tokens_used: response[:tokens_used], cost: response[:cost] }
    }
  end

  def extract_title_from_response(content)
    # Extract a title from the AI response
    lines = content.split("\n")
    lines.first&.strip || "AI Insight"
  end

  def extract_improvements_from_response(content)
    # Extract improvement suggestions from AI response
    []
  end

  def extract_recommendations_from_response(content)
    # Extract recommendations from AI response
    []
  end
end