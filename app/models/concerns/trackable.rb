# frozen_string_literal: true

# Concern for models that need analytics and tracking functionality
module Trackable
  extend ActiveSupport::Concern

  included do
    # Add common tracking fields if they don't exist
    # These would be added via migrations:
    # - last_activity_at: timestamp
    # - activity_count: integer
    # - engagement_score: decimal
    # - tracking_data: jsonb
    
    scope :active, -> { where('last_activity_at >= ?', 30.days.ago) }
    scope :inactive, -> { where('last_activity_at < ? OR last_activity_at IS NULL', 30.days.ago) }
    scope :highly_engaged, -> { where('engagement_score >= ?', 80) }
    scope :low_engagement, -> { where('engagement_score <= ?', 20) }
    
    before_save :update_engagement_score, if: :should_recalculate_engagement?
  end

  class_methods do
    def with_activity_since(date)
      where('last_activity_at >= ?', date)
    end

    def engagement_distribution
      {
        highly_engaged: highly_engaged.count,
        moderately_engaged: where(engagement_score: 40..79).count,
        low_engagement: low_engagement.count,
        no_engagement: where(engagement_score: nil).count
      }
    end

    def activity_summary(period = 30.days)
      since_date = period.ago
      
      {
        total_records: count,
        active_records: active.count,
        inactive_records: inactive.count,
        new_records: where('created_at >= ?', since_date).count,
        updated_records: where('updated_at >= ?', since_date).count
      }
    end
  end

  # Track an activity for this record
  def track_activity!(activity_type, metadata = {})
    now = Time.current
    
    # Update tracking fields
    self.last_activity_at = now
    self.activity_count = (self.activity_count || 0) + 1
    
    # Store activity metadata
    self.tracking_data ||= {}
    self.tracking_data['recent_activities'] ||= []
    self.tracking_data['recent_activities'].unshift({
      type: activity_type,
      timestamp: now.iso8601,
      metadata: metadata
    })
    
    # Keep only last 50 activities
    self.tracking_data['recent_activities'] = self.tracking_data['recent_activities'].first(50)
    
    # Update type-specific counters
    counter_key = "#{activity_type}_count"
    self.tracking_data[counter_key] = (self.tracking_data[counter_key] || 0) + 1
    
    save!
  end

  # Get activity history
  def activity_history(limit = 20)
    return [] unless tracking_data.present?
    
    activities = tracking_data['recent_activities'] || []
    activities.first(limit).map do |activity|
      {
        type: activity['type'],
        timestamp: Time.parse(activity['timestamp']),
        metadata: activity['metadata'] || {}
      }
    end
  end

  # Get specific activity count
  def activity_count_for(activity_type)
    return 0 unless tracking_data.present?
    
    tracking_data["#{activity_type}_count"] || 0
  end

  # Calculate days since last activity
  def days_since_last_activity
    return nil unless last_activity_at.present?
    
    (Date.current - last_activity_at.to_date).to_i
  end

  # Check if record is considered active
  def active?
    last_activity_at.present? && last_activity_at >= 30.days.ago
  end

  # Get engagement level as human-readable string
  def engagement_level
    return 'unknown' unless engagement_score.present?
    
    case engagement_score
    when 80..100
      'highly_engaged'
    when 60..79
      'moderately_engaged'
    when 40..59
      'somewhat_engaged'
    when 20..39
      'barely_engaged'
    else
      'not_engaged'
    end
  end

  # Get recent activity summary
  def recent_activity_summary(days = 7)
    since_date = days.days.ago
    
    activities = activity_history(100).select { |a| a[:timestamp] >= since_date }
    
    {
      total_activities: activities.count,
      activity_types: activities.group_by { |a| a[:type] }.transform_values(&:count),
      most_recent_activity: activities.first,
      average_daily_activities: activities.count.to_f / days
    }
  end

  private

  def should_recalculate_engagement?
    # Recalculate engagement score if relevant fields changed
    trackable_fields = %w[last_activity_at activity_count]
    trackable_fields.any? { |field| attribute_changed?(field) }
  end

  def update_engagement_score
    # This method should be implemented by the including model
    # to provide model-specific engagement calculation
    self.engagement_score = calculate_engagement_score if respond_to?(:calculate_engagement_score, true)
  end

  # Default engagement score calculation (can be overridden)
  def calculate_engagement_score
    base_score = 0
    
    # Score based on recent activity
    if last_activity_at.present?
      days_since_activity = days_since_last_activity
      
      base_score += case days_since_activity
                    when 0..7
                      40
                    when 8..30
                      25
                    when 31..90
                      10
                    else
                      0
                    end
    end
    
    # Score based on activity frequency
    if activity_count.present? && activity_count > 0
      # Normalize activity count (assuming 50+ activities is maximum score)
      activity_score = [activity_count, 50].min
      base_score += (activity_score * 0.6).round
    end
    
    # Score based on recency of creation (newer records get slight boost)
    if created_at.present?
      days_since_creation = (Date.current - created_at.to_date).to_i
      if days_since_creation <= 30
        base_score += 10
      elsif days_since_creation <= 90
        base_score += 5
      end
    end
    
    # Cap at 100
    [base_score, 100].min
  end
end
