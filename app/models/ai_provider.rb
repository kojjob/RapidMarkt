# frozen_string_literal: true

class AiProvider < ApplicationRecord
  belongs_to :account
  has_many :ai_usage_logs, dependent: :destroy
  has_many :content_generations, dependent: :destroy

  validates :name, presence: true
  validates :provider_type, presence: true, inclusion: { in: %w[openai anthropic google cohere huggingface custom] }
  validates :api_endpoint, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp }
  validates :status, inclusion: { in: %w[active inactive maintenance] }

  encrypts :api_key
  encrypts :api_secret, deterministic: false

  scope :active, -> { where(status: 'active') }
  scope :by_provider_type, ->(type) { where(provider_type: type) }

  enum :priority, { primary: 0, secondary: 1, fallback: 2 }

  # Configuration for different providers
  PROVIDER_CONFIGS = {
    'openai' => {
      models: ['gpt-4', 'gpt-4-turbo', 'gpt-3.5-turbo'],
      capabilities: ['text_generation', 'chat_completion', 'embeddings'],
      rate_limits: { requests_per_minute: 3500, tokens_per_minute: 90000 }
    },
    'anthropic' => {
      models: ['claude-3-opus', 'claude-3-sonnet', 'claude-3-haiku'],
      capabilities: ['text_generation', 'chat_completion', 'analysis'],
      rate_limits: { requests_per_minute: 1000, tokens_per_minute: 40000 }
    },
    'google' => {
      models: ['gemini-pro', 'gemini-pro-vision', 'text-bison'],
      capabilities: ['text_generation', 'chat_completion', 'multimodal'],
      rate_limits: { requests_per_minute: 60, tokens_per_minute: 32000 }
    },
    'cohere' => {
      models: ['command', 'command-light', 'command-nightly'],
      capabilities: ['text_generation', 'embeddings', 'classification'],
      rate_limits: { requests_per_minute: 1000, tokens_per_minute: 40000 }
    }
  }.freeze

  def provider_config
    PROVIDER_CONFIGS[provider_type] || {}
  end

  def available_models
    provider_config['models'] || []
  end

  def capabilities
    provider_config['capabilities'] || []
  end

  def rate_limits
    provider_config['rate_limits'] || {}
  end

  def supports_capability?(capability)
    capabilities.include?(capability.to_s)
  end

  def within_rate_limit?
    return true unless rate_limits.any?

    current_minute = Time.current.beginning_of_minute
    recent_usage = ai_usage_logs.where(created_at: current_minute..Time.current)
    
    requests_count = recent_usage.count
    tokens_count = recent_usage.sum(:tokens_used)

    requests_count < rate_limits[:requests_per_minute] &&
      tokens_count < rate_limits[:tokens_per_minute]
  end

  def health_check
    return false unless active?
    return false unless within_rate_limit?

    # Perform a simple API health check
    begin
      response = perform_health_check_request
      update(last_health_check: Time.current, health_status: 'healthy')
      true
    rescue => e
      update(last_health_check: Time.current, health_status: 'unhealthy', last_error: e.message)
      false
    end
  end

  def usage_stats(period = 1.day)
    logs = ai_usage_logs.where(created_at: period.ago..Time.current)
    {
      total_requests: logs.count,
      total_tokens: logs.sum(:tokens_used),
      total_cost: logs.sum(:cost),
      average_response_time: logs.average(:response_time_ms),
      success_rate: logs.where(success: true).count.to_f / logs.count * 100
    }
  end

  private

  def perform_health_check_request
    require 'net/http'
    require 'json'
    
    case provider_type
    when 'openai'
      perform_openai_health_check
    when 'anthropic'
      perform_anthropic_health_check
    when 'google'
      perform_google_health_check
    when 'cohere'
      perform_cohere_health_check
    else
      perform_generic_health_check
    end
  end

  def perform_openai_health_check
    uri = URI('https://api.openai.com/v1/models')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    
    response = http.request(request)
    response.code == '200'
  end

  def perform_anthropic_health_check
    uri = URI('https://api.anthropic.com/v1/messages')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['x-api-key'] = api_key
    request['Content-Type'] = 'application/json'
    request['anthropic-version'] = '2023-06-01'
    
    # Minimal test message
    request.body = {
      model: 'claude-3-haiku-20240307',
      max_tokens: 1,
      messages: [{ role: 'user', content: 'Hi' }]
    }.to_json
    
    response = http.request(request)
    [200, 201].include?(response.code.to_i)
  end

  def perform_google_health_check
    # For Google AI/Gemini, we'll check the generateContent endpoint
    uri = URI("https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=#{api_key}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    # Minimal test content
    request.body = {
      contents: [{
        parts: [{ text: 'Hi' }]
      }]
    }.to_json
    
    response = http.request(request)
    response.code == '200'
  end

  def perform_cohere_health_check
    uri = URI('https://api.cohere.ai/v1/generate')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 10
    
    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Content-Type'] = 'application/json'
    
    # Minimal test generation
    request.body = {
      model: 'command-light',
      prompt: 'Hi',
      max_tokens: 1
    }.to_json
    
    response = http.request(request)
    response.code == '200'
  end

  def perform_generic_health_check
    return false unless api_endpoint.present?
    
    uri = URI(api_endpoint)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    http.read_timeout = 10
    
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}" if api_key.present?
    
    response = http.request(request)
    [200, 201, 204].include?(response.code.to_i)
  rescue => e
    Rails.logger.error "Generic health check failed: #{e.message}"
    false
  end
end