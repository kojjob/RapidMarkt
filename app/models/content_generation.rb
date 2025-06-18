# frozen_string_literal: true

class ContentGeneration < ApplicationRecord
  belongs_to :account
  belongs_to :ai_provider
  belongs_to :user
  belongs_to :generatable, polymorphic: true, optional: true # campaign, template, etc.
  has_many :ai_usage_logs, as: :loggable, dependent: :destroy

  validates :content_type, presence: true, inclusion: { 
    in: %w[email_subject email_body social_post blog_post ad_copy 
           landing_page_copy product_description newsletter_content 
           campaign_name template_design push_notification sms_content]
  }
  validates :prompt, presence: true, length: { maximum: 2000 }
  validates :generated_content, presence: true, allow_blank: true
  validates :status, inclusion: { in: %w[pending processing completed failed draft approved rejected published archived] }
  validates :quality_score, numericality: { in: 0..100 }, allow_nil: true

  scope :by_type, ->(type) { where(content_type: type) }
  scope :by_status, ->(status) { where(status: status) }
  scope :approved, -> { where(status: 'approved') }
  scope :published, -> { where(status: 'published') }
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :recent, ->(period = 1.week) { where(created_at: period.ago..Time.current) }
  scope :high_quality, -> { where('quality_score >= ?', 80) }
  scope :by_provider, ->(provider_id) { where(ai_provider_id: provider_id) }

  # Content type configurations
  CONTENT_CONFIGS = {
    'email_subject' => {
      max_length: 60,
      min_length: 10,
      quality_factors: ['clarity', 'urgency', 'personalization', 'spam_score'],
      performance_metrics: ['open_rate', 'click_rate']
    },
    'email_body' => {
      max_length: 2000,
      min_length: 100,
      quality_factors: ['readability', 'engagement', 'call_to_action', 'personalization'],
      performance_metrics: ['click_rate', 'conversion_rate', 'unsubscribe_rate']
    },
    'social_post' => {
      max_length: 280,
      min_length: 20,
      quality_factors: ['engagement_potential', 'hashtag_usage', 'visual_appeal'],
      performance_metrics: ['likes', 'shares', 'comments', 'click_rate']
    },
    'ad_copy' => {
      max_length: 150,
      min_length: 25,
      quality_factors: ['persuasiveness', 'clarity', 'call_to_action', 'target_relevance'],
      performance_metrics: ['click_rate', 'conversion_rate', 'cost_per_click']
    }
  }.freeze

  before_validation :calculate_quality_score, if: :generated_content_changed?
  after_create :log_generation_metrics

  def self.performance_summary(period = 1.month)
    generations = where(created_at: period.ago..Time.current)
    
    {
      total_generated: generations.count,
      by_type: generations.group(:content_type).count,
      by_status: generations.group(:status).count,
      by_provider: generations.joins(:ai_provider).group('ai_providers.name').count,
      average_quality: generations.average(:quality_score)&.round(2),
      top_performing: generations.where('performance_score > ?', 80).count,
      total_cost: generations.joins(:ai_usage_logs).sum('ai_usage_logs.cost')
    }
  end

  def self.content_analytics(content_type, period = 1.month)
    generations = where(content_type: content_type, created_at: period.ago..Time.current)
    
    {
      total_count: generations.count,
      average_quality: generations.average(:quality_score)&.round(2),
      approval_rate: (generations.approved.count.to_f / generations.count * 100).round(2),
      performance_distribution: generations.group_by { |g| performance_tier(g.performance_score) },
      top_prompts: generations.group(:prompt).order('COUNT(*) DESC').limit(5).count,
      provider_comparison: generations.joins(:ai_provider)
        .group('ai_providers.name')
        .average(:quality_score)
    }
  end

  def self.optimization_insights(account)
    insights = []
    recent_generations = account.content_generations.recent(2.weeks)
    
    # Low quality content insight
    low_quality_count = recent_generations.where('quality_score < ?', 60).count
    if low_quality_count > recent_generations.count * 0.3
      insights << {
        type: 'quality_improvement',
        message: "#{low_quality_count} recent generations have low quality scores. Consider refining prompts.",
        action: 'Review and optimize prompts for better results'
      }
    end
    
    # Provider performance comparison
    provider_performance = recent_generations
      .joins(:ai_provider)
      .group('ai_providers.name')
      .average(:quality_score)
    
    if provider_performance.values.max - provider_performance.values.min > 20
      best_provider = provider_performance.max_by { |_, score| score }
      insights << {
        type: 'provider_optimization',
        message: "#{best_provider[0]} is generating higher quality content (#{best_provider[1].round(1)}% avg).",
        action: 'Consider using this provider for similar content types'
      }
    end
    
    insights
  end

  def content_config
    CONTENT_CONFIGS[content_type] || {}
  end

  def within_length_limits?
    config = content_config
    return true unless config[:max_length] && config[:min_length]
    
    length = generated_content.length
    length >= config[:min_length] && length <= config[:max_length]
  end

  def performance_tier
    self.class.performance_tier(performance_score)
  end

  def self.performance_tier(score)
    case score
    when 90..100 then 'excellent'
    when 80..89 then 'good'
    when 60..79 then 'average'
    when 40..59 then 'below_average'
    else 'poor'
    end
  end

  def approve!
    update!(status: 'approved', approved_at: Time.current, approved_by: Current.user&.id)
  end

  def reject!(reason = nil)
    update!(status: 'rejected', rejected_at: Time.current, rejection_reason: reason)
  end

  def publish!
    update!(status: 'published', published_at: Time.current)
  end

  def calculate_roi
    return 0 unless performance_metrics.present? && generation_cost > 0
    
    # Calculate ROI based on performance metrics and generation cost
    revenue_generated = performance_metrics['revenue'] || 0
    (revenue_generated - generation_cost) / generation_cost * 100
  end

  def generation_cost
    ai_usage_logs.sum(:cost)
  end

  def tokens_used
    ai_usage_logs.sum(:tokens_used)
  end

  def generation_time
    ai_usage_logs.sum(:response_time_ms)
  end

  def update_performance_metrics(metrics)
    self.performance_metrics = (performance_metrics || {}).merge(metrics)
    calculate_performance_score
    save!
  end

  def spam_score
    # Simple spam detection based on content analysis
    spam_indicators = [
      generated_content.scan(/[A-Z]{3,}/).length, # Excessive caps
      generated_content.scan(/!{2,}/).length,     # Multiple exclamation marks
      generated_content.scan(/\${1,}/).length,    # Dollar signs
      generated_content.scan(/\b(free|urgent|limited|act now)\b/i).length # Spam words
    ]
    
    total_indicators = spam_indicators.sum
    content_length = generated_content.length
    
    # Normalize score (0-100, higher = more spammy)
    [(total_indicators.to_f / content_length * 1000).round, 100].min
  end

  private

  def calculate_quality_score
    return unless generated_content.present?
    
    scores = []
    
    # Length appropriateness (0-25 points)
    if within_length_limits?
      scores << 25
    else
      config = content_config
      if config[:max_length]
        length_ratio = generated_content.length.to_f / config[:max_length]
        scores << [25 - (length_ratio - 1).abs * 10, 0].max
      else
        scores << 20
      end
    end
    
    # Readability (0-25 points)
    readability_score = calculate_readability_score
    scores << readability_score
    
    # Spam score (0-25 points, inverted)
    spam_penalty = spam_score
    scores << [25 - spam_penalty / 4, 0].max
    
    # Content structure (0-25 points)
    structure_score = calculate_structure_score
    scores << structure_score
    
    self.quality_score = scores.sum
  end

  def calculate_readability_score
    # Simple readability calculation
    sentences = generated_content.split(/[.!?]+/).length
    words = generated_content.split(/\s+/).length
    
    return 0 if sentences.zero?
    
    avg_sentence_length = words.to_f / sentences
    
    # Optimal sentence length is 15-20 words
    if avg_sentence_length.between?(15, 20)
      25
    elsif avg_sentence_length.between?(10, 25)
      20
    else
      15
    end
  end

  def calculate_structure_score
    score = 0
    
    # Has clear call-to-action
    cta_words = %w[click buy subscribe download learn more sign up get started]
    if cta_words.any? { |word| generated_content.downcase.include?(word) }
      score += 10
    end
    
    # Has engaging opening
    first_sentence = generated_content.split(/[.!?]/).first
    if first_sentence && (first_sentence.include?('?') || first_sentence.length < 50)
      score += 8
    end
    
    # Proper punctuation
    if generated_content.match?(/[.!?]$/)
      score += 7
    end
    
    score
  end

  def calculate_performance_score
    return unless performance_metrics.present?
    
    config = content_config
    metrics = config['performance_metrics'] || []
    
    scores = metrics.map do |metric|
      value = performance_metrics[metric]
      next 0 unless value
      
      # Normalize different metrics to 0-100 scale
      case metric
      when 'open_rate', 'click_rate'
        [value * 5, 100].min # 20% = 100 points
      when 'conversion_rate'
        [value * 20, 100].min # 5% = 100 points
      when 'likes', 'shares', 'comments'
        [Math.log10(value + 1) * 20, 100].min # Logarithmic scale
      else
        value
      end
    end
    
    self.performance_score = scores.any? ? scores.sum / scores.length : 0
  end

  def progress_percentage
    # Use stored progress if available, otherwise calculate based on status
    return read_attribute(:progress_percentage) if read_attribute(:progress_percentage) && read_attribute(:progress_percentage) > 0
    
    case status
    when 'pending'
      0
    when 'processing'
      50
    when 'completed', 'draft', 'approved', 'published'
      100
    when 'failed', 'rejected', 'archived'
      100
    else
      0
    end
  end
  
  def update_progress(percentage, message = nil)
    update_columns(
      progress_percentage: percentage,
      error_message: message,
      updated_at: Time.current
    )
  end
  
  def mark_as_processing!
    update_columns(
      status: 'processing',
      started_at: Time.current,
      progress_percentage: 10
    )
  end
  
  def mark_as_completed!(content = nil)
    updates = {
      status: 'completed',
      completed_at: Time.current,
      progress_percentage: 100
    }
    updates[:generated_content] = content if content.present?
    update_columns(updates)
  end
  
  def mark_as_failed!(error_message)
    update_columns(
      status: 'failed',
      completed_at: Time.current,
      progress_percentage: 100,
      error_message: error_message
    )
  end

  def log_generation_metrics
    # This would typically be called after the AI generation is complete
    # to log the usage metrics
  end
end