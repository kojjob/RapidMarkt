# frozen_string_literal: true

class AiInsight < ApplicationRecord
  belongs_to :account
  belongs_to :ai_provider
  belongs_to :user, optional: true
  belongs_to :insightable, polymorphic: true, optional: true # campaign, template, contact, etc.

  validates :insight_type, presence: true, inclusion: { 
    in: %w[performance_optimization content_suggestion audience_analysis 
           campaign_recommendation template_improvement engagement_prediction 
           cost_optimization trend_analysis competitive_analysis]
  }
  validates :title, presence: true, length: { maximum: 255 }
  validates :content, presence: true
  validates :confidence_score, presence: true, numericality: { in: 0..100 }
  validates :priority, inclusion: { in: %w[low medium high critical] }
  validates :status, inclusion: { in: %w[pending reviewed implemented dismissed] }

  scope :by_type, ->(type) { where(insight_type: type) }
  scope :by_priority, ->(priority) { where(priority: priority) }
  scope :by_status, ->(status) { where(status: status) }
  scope :high_confidence, -> { where('confidence_score >= ?', 80) }
  scope :actionable, -> { where(status: ['pending', 'reviewed']) }
  scope :recent, ->(period = 1.week) { where(created_at: period.ago..Time.current) }
  scope :ordered_by_priority, -> { order(Arel.sql("CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 ELSE 4 END")) }

  # Metadata structure for different insight types
  INSIGHT_SCHEMAS = {
    'performance_optimization' => {
      required_fields: ['current_metric', 'suggested_improvement', 'expected_impact'],
      optional_fields: ['implementation_steps', 'timeline', 'resources_needed']
    },
    'content_suggestion' => {
      required_fields: ['content_type', 'suggested_content', 'target_audience'],
      optional_fields: ['tone', 'length', 'keywords', 'call_to_action']
    },
    'audience_analysis' => {
      required_fields: ['segment_name', 'characteristics', 'behavior_patterns'],
      optional_fields: ['preferences', 'optimal_timing', 'channel_preferences']
    },
    'campaign_recommendation' => {
      required_fields: ['campaign_type', 'target_segments', 'recommended_channels'],
      optional_fields: ['budget_allocation', 'timeline', 'success_metrics']
    }
  }.freeze

  before_validation :set_defaults
  after_create :notify_relevant_users

  def self.generate_dashboard_insights(account, limit = 5)
    insights = []
    
    # Performance insights
    insights.concat(generate_performance_insights(account))
    
    # Content suggestions
    insights.concat(generate_content_suggestions(account))
    
    # Audience insights
    insights.concat(generate_audience_insights(account))
    
    # Campaign recommendations
    insights.concat(generate_campaign_recommendations(account))
    
    insights.sort_by { |insight| [-insight.priority_score, -insight.confidence_score] }.first(limit)
  end

  def self.generate_performance_insights(account)
    insights = []
    
    # Analyze recent campaign performance
    recent_campaigns = account.campaigns.where(created_at: 1.month.ago..Time.current)
    
    if recent_campaigns.any?
      avg_open_rate = recent_campaigns.average(:open_rate) || 0
      avg_click_rate = recent_campaigns.average(:click_rate) || 0
      
      if avg_open_rate < 20 # Industry average is ~20%
        insights << new(
          account: account,
          insight_type: 'performance_optimization',
          title: 'Low Email Open Rates Detected',
          content: "Your average open rate (#{avg_open_rate.round(1)}%) is below industry standards. Consider improving subject lines and sender reputation.",
          confidence_score: 85,
          priority: 'high',
          metadata: {
            current_metric: avg_open_rate,
            suggested_improvement: 'Subject line optimization',
            expected_impact: '15-25% improvement in open rates',
            implementation_steps: ['A/B test subject lines', 'Personalize sender name', 'Optimize send times']
          }
        )
      end
    end
    
    insights
  end

  def self.generate_content_suggestions(account)
    insights = []
    
    # Analyze content performance and suggest improvements
    top_performing_templates = account.templates
      .joins(:campaigns)
      .where(campaigns: { created_at: 3.months.ago..Time.current })
      .group('templates.id')
      .order('AVG(campaigns.open_rate) DESC')
      .limit(3)
    
    if top_performing_templates.any?
      insights << new(
        account: account,
        insight_type: 'content_suggestion',
        title: 'Replicate High-Performing Content Patterns',
        content: 'Your top-performing templates share common characteristics that you can apply to new campaigns.',
        confidence_score: 75,
        priority: 'medium',
        metadata: {
          content_type: 'email_template',
          suggested_content: 'Templates with personal stories and clear CTAs',
          target_audience: 'All segments',
          implementation_steps: ['Analyze top templates', 'Extract common elements', 'Apply to new campaigns']
        }
      )
    end
    
    insights
  end

  def self.generate_audience_insights(account)
    insights = []
    
    # Analyze contact engagement patterns
    engaged_contacts = account.contacts.where('last_opened_at > ?', 30.days.ago)
    total_contacts = account.contacts.count
    
    if total_contacts > 0
      engagement_rate = (engaged_contacts.count.to_f / total_contacts * 100).round(1)
      
      if engagement_rate < 30
        insights << new(
          account: account,
          insight_type: 'audience_analysis',
          title: 'Low Audience Engagement Detected',
          content: "Only #{engagement_rate}% of your contacts have engaged recently. Consider re-engagement campaigns.",
          confidence_score: 80,
          priority: 'high',
          metadata: {
            segment_name: 'Inactive Subscribers',
            characteristics: 'No engagement in 30+ days',
            behavior_patterns: 'Low open and click rates',
            recommended_action: 'Re-engagement campaign'
          }
        )
      end
    end
    
    insights
  end

  def self.generate_campaign_recommendations(account)
    insights = []
    
    # Seasonal and timing recommendations
    current_month = Time.current.month
    
    case current_month
    when 11, 12 # November, December
      insights << new(
        account: account,
        insight_type: 'campaign_recommendation',
        title: 'Holiday Season Campaign Opportunity',
        content: 'Holiday campaigns typically see 20-30% higher engagement. Consider launching festive campaigns.',
        confidence_score: 70,
        priority: 'medium',
        metadata: {
          campaign_type: 'Holiday/Seasonal',
          target_segments: 'All active subscribers',
          recommended_channels: ['email', 'social'],
          optimal_timing: 'Early to mid-month'
        }
      )
    end
    
    insights
  end

  def priority_score
    case priority
    when 'critical' then 4
    when 'high' then 3
    when 'medium' then 2
    when 'low' then 1
    else 0
    end
  end

  def actionable?
    %w[pending reviewed].include?(status)
  end

  def implemented?
    status == 'implemented'
  end

  def mark_as_implemented!
    update!(status: 'implemented', implemented_at: Time.current)
  end

  def mark_as_dismissed!
    update!(status: 'dismissed', dismissed_at: Time.current)
  end

  def schema
    INSIGHT_SCHEMAS[insight_type] || {}
  end

  def validate_metadata
    return true unless schema.any?
    
    required_fields = schema['required_fields'] || []
    missing_fields = required_fields - (metadata&.keys || [])
    
    missing_fields.empty?
  end

  private

  def set_defaults
    self.status ||= 'pending'
    self.priority ||= 'medium'
    self.confidence_score ||= 50
    self.metadata ||= {}
  end

  def notify_relevant_users
    # Send notifications for high-priority insights
    if priority.in?(['high', 'critical'])
      # NotificationService.notify_insight_created(self)
    end
  end
end