# frozen_string_literal: true

class AnalyticsProcessorJob < ApplicationJob
  queue_as QueuePriorities::MAINTENANCE

  def perform
    Rails.logger.info "Starting analytics processing at #{Time.current}"
    
    processing_results = {
      accounts_processed: 0,
      engagement_scores_updated: 0,
      performance_metrics_calculated: 0,
      errors: []
    }

    # Process analytics for each account
    Account.find_each do |account|
      begin
        process_account_analytics(account)
        processing_results[:accounts_processed] += 1
      rescue => e
        error_msg = "Failed to process analytics for account #{account.id}: #{e.message}"
        Rails.logger.error error_msg
        processing_results[:errors] << error_msg
      end
    end

    # Update global engagement scores
    processing_results[:engagement_scores_updated] = update_engagement_scores

    # Calculate performance metrics
    processing_results[:performance_metrics_calculated] = calculate_performance_metrics

    # Generate daily analytics summary
    generate_daily_summary

    Rails.logger.info "Analytics processing completed: #{processing_results}"
    
    # Create audit log
    AuditLog.create!(
      action: 'analytics_processing',
      details: "Analytics processing completed: #{processing_results}",
      resource_type: 'System',
      user: nil,
      account: nil
    )

    processing_results
  rescue => e
    Rails.logger.error "Analytics processing failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise e
  end

  private

  def process_account_analytics(account)
    # Update contact engagement scores
    ContactManagementService.new(account: account).calculate_engagement_scores

    # Process campaign performance analytics
    recent_campaigns = account.campaigns.where('created_at >= ?', 7.days.ago)
    recent_campaigns.find_each do |campaign|
      # Update campaign engagement scores
      campaign.update_column(:engagement_score, campaign.calculate_engagement_score)
    end

    # Process template analytics
    recent_templates = account.templates.where('updated_at >= ?', 7.days.ago)
    recent_templates.find_each do |template|
      # Update template engagement scores
      template.update_column(:engagement_score, template.calculate_engagement_score)
    end

    # Process automation analytics
    account.email_automations.active.find_each do |automation|
      # Update automation performance metrics
      automation.update_column(:engagement_score, calculate_automation_engagement_score(automation))
    end
  end

  def update_engagement_scores
    updated_count = 0
    
    # Update contact engagement scores in batches
    Contact.find_in_batches(batch_size: 1000) do |contacts|
      contacts.each do |contact|
        new_score = contact.calculate_engagement_score
        if contact.engagement_score != new_score
          contact.update_column(:engagement_score, new_score)
          updated_count += 1
        end
      end
    end

    updated_count
  end

  def calculate_performance_metrics
    metrics_calculated = 0

    # Calculate daily performance metrics for campaigns
    Campaign.sent.where('sent_at >= ?', 1.day.ago).find_each do |campaign|
      # Update open and click rates based on actual data
      total_recipients = campaign.campaign_contacts.count
      next if total_recipients == 0

      opens = campaign.campaign_contacts.where.not(opened_at: nil).count
      clicks = campaign.campaign_contacts.where.not(clicked_at: nil).count

      new_open_rate = (opens.to_f / total_recipients * 100).round(2)
      new_click_rate = (clicks.to_f / total_recipients * 100).round(2)

      if campaign.open_rate != new_open_rate || campaign.click_rate != new_click_rate
        campaign.update_columns(
          open_rate: new_open_rate,
          click_rate: new_click_rate
        )
        metrics_calculated += 1
      end
    end

    metrics_calculated
  end

  def calculate_automation_engagement_score(automation)
    base_score = 0
    
    # Score based on enrollment rate
    total_enrollments = automation.total_enrollments
    base_score += [total_enrollments * 2, 30].min
    
    # Score based on completion rate
    completion_rate = automation.completion_rate
    base_score += [completion_rate * 0.4, 40].min
    
    # Score based on recent activity
    if automation.last_activity_at.present?
      days_since_activity = (Date.current - automation.last_activity_at.to_date).to_i
      base_score += case days_since_activity
                    when 0..7 then 20
                    when 8..30 then 10
                    when 31..90 then 5
                    else 0
                    end
    end
    
    # Score based on status
    base_score += case automation.status
                  when 'active' then 10
                  when 'paused' then 5
                  else 0
                  end

    [base_score, 100].min
  end

  def generate_daily_summary
    # Generate a daily analytics summary for system monitoring
    summary = {
      date: Date.current,
      total_accounts: Account.count,
      active_accounts: Account.joins(:campaigns).where('campaigns.created_at >= ?', 30.days.ago).distinct.count,
      total_campaigns: Campaign.count,
      campaigns_sent_today: Campaign.where('sent_at >= ?', Date.current.beginning_of_day).count,
      total_contacts: Contact.count,
      active_contacts: Contact.where('last_activity_at >= ?', 30.days.ago).count,
      total_automations: EmailAutomation.count,
      active_automations: EmailAutomation.active.count,
      system_health: calculate_system_health
    }

    # Store summary in cache for dashboard usage
    Rails.cache.write("daily_analytics_summary:#{Date.current}", summary, expires_in: 25.hours)
    
    Rails.logger.info "Generated daily analytics summary: #{summary}"
    summary
  end

  def calculate_system_health
    health_score = 100
    
    # Check job queue health
    begin
      failed_jobs_count = SolidQueue::Job.failed.where('created_at >= ?', 24.hours.ago).count
      health_score -= [failed_jobs_count * 2, 20].min
    rescue => e
      Rails.logger.warn "Could not check job queue health: #{e.message}"
      health_score -= 10
    end
    
    # Check database performance
    begin
      slow_queries = ActiveRecord::Base.connection.execute(
        "SELECT COUNT(*) FROM pg_stat_activity WHERE state = 'active' AND query_start < NOW() - INTERVAL '30 seconds'"
      ).first['count'].to_i
      
      health_score -= [slow_queries * 5, 15].min
    rescue => e
      Rails.logger.warn "Could not check database performance: #{e.message}"
    end
    
    # Check storage usage
    begin
      if ActiveStorage::Blob.count > 10000
        health_score -= 5 # Large number of blobs might affect performance
      end
    rescue => e
      Rails.logger.warn "Could not check storage usage: #{e.message}"
    end
    
    [health_score, 0].max
  end
end
