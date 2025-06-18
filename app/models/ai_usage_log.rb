# frozen_string_literal: true

class AiUsageLog < ApplicationRecord
  belongs_to :ai_provider
  belongs_to :account
  belongs_to :user, optional: true
  belongs_to :loggable, polymorphic: true, optional: true # campaign, template, etc.

  validates :operation_type, presence: true, inclusion: { 
    in: %w[text_generation chat_completion embeddings analysis image_generation content_optimization]
  }
  validates :model_used, presence: true
  validates :tokens_used, presence: true, numericality: { greater_than: 0 }
  validates :response_time_ms, presence: true, numericality: { greater_than: 0 }
  validates :cost, presence: true, numericality: { greater_than_or_equal_to: 0 }

  scope :successful, -> { where(success: true) }
  scope :failed, -> { where(success: false) }
  scope :by_operation, ->(type) { where(operation_type: type) }
  scope :by_model, ->(model) { where(model_used: model) }
  scope :recent, ->(period = 1.day) { where(created_at: period.ago..Time.current) }
  scope :this_month, -> { where(created_at: Time.current.beginning_of_month..Time.current) }
  scope :today, -> { where(created_at: Time.current.beginning_of_day..Time.current) }

  # Cost calculation constants (per 1K tokens)
  MODEL_COSTS = {
    'gpt-4' => { input: 0.03, output: 0.06 },
    'gpt-4-turbo' => { input: 0.01, output: 0.03 },
    'gpt-3.5-turbo' => { input: 0.0015, output: 0.002 },
    'claude-3-opus' => { input: 0.015, output: 0.075 },
    'claude-3-sonnet' => { input: 0.003, output: 0.015 },
    'claude-3-haiku' => { input: 0.00025, output: 0.00125 },
    'gemini-pro' => { input: 0.0005, output: 0.0015 },
    'command' => { input: 0.001, output: 0.002 }
  }.freeze

  before_create :calculate_cost

  def self.total_cost(period = 1.month)
    where(created_at: period.ago..Time.current).sum(:cost)
  end

  def self.total_tokens(period = 1.month)
    where(created_at: period.ago..Time.current).sum(:tokens_used)
  end

  def self.average_response_time(period = 1.month)
    where(created_at: period.ago..Time.current).average(:response_time_ms)
  end

  def self.success_rate(period = 1.month)
    logs = where(created_at: period.ago..Time.current)
    return 0 if logs.count.zero?
    
    (logs.successful.count.to_f / logs.count * 100).round(2)
  end

  def self.usage_by_operation(period = 1.month)
    where(created_at: period.ago..Time.current)
      .group(:operation_type)
      .group_by_day(:created_at)
      .sum(:tokens_used)
  end

  def self.cost_by_provider(period = 1.month)
    joins(:ai_provider)
      .where(created_at: period.ago..Time.current)
      .group('ai_providers.name')
      .sum(:cost)
  end

  def self.performance_metrics(period = 1.month)
    logs = where(created_at: period.ago..Time.current)
    
    {
      total_requests: logs.count,
      successful_requests: logs.successful.count,
      failed_requests: logs.failed.count,
      total_tokens: logs.sum(:tokens_used),
      total_cost: logs.sum(:cost),
      average_response_time: logs.average(:response_time_ms)&.round(2),
      success_rate: success_rate(period),
      cost_per_token: logs.sum(:cost) / logs.sum(:tokens_used).to_f,
      requests_by_day: logs.group_by_day(:created_at).count,
      cost_by_day: logs.group_by_day(:created_at).sum(:cost)
    }
  end

  def self.provider_comparison(period = 1.month)
    joins(:ai_provider)
      .where(created_at: period.ago..Time.current)
      .group('ai_providers.name')
      .group('ai_providers.provider_type')
      .select(
        'ai_providers.name',
        'ai_providers.provider_type',
        'COUNT(*) as request_count',
        'SUM(tokens_used) as total_tokens',
        'SUM(cost) as total_cost',
        'AVG(response_time_ms) as avg_response_time',
        'SUM(CASE WHEN success THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as success_rate'
      )
  end

  def cost_per_token
    return 0 if tokens_used.zero?
    cost / tokens_used
  end

  def efficiency_score
    # Higher score = better efficiency (lower cost, faster response)
    return 0 unless success? && response_time_ms > 0 && cost > 0
    
    # Normalize metrics (lower is better for both cost and response time)
    cost_score = 1.0 / (cost_per_token * 1000 + 1)
    speed_score = 1.0 / (response_time_ms / 1000.0 + 1)
    
    (cost_score + speed_score) / 2 * 100
  end

  private

  def calculate_cost
    model_cost = MODEL_COSTS[model_used]
    return unless model_cost

    # Estimate input/output token split (rough approximation)
    input_tokens = (tokens_used * 0.7).round
    output_tokens = tokens_used - input_tokens

    self.cost = (
      (input_tokens / 1000.0) * model_cost[:input] +
      (output_tokens / 1000.0) * model_cost[:output]
    ).round(6)
  end
end