# frozen_string_literal: true

class CampaignService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attr_reader :campaign, :account, :errors

  def initialize(campaign: nil, account: nil)
    @campaign = campaign
    @account = account || campaign&.account
    @errors = ActiveModel::Errors.new(self)
  end

  # Create a new campaign with proper validation and setup
  def create(params)
    @campaign = @account.campaigns.build(params.except(:contact_ids, :tag_ids))
    @campaign.user = Current.user if Current.user

    ApplicationRecord.transaction do
      if @campaign.save
        attach_contacts(params[:contact_ids]) if params[:contact_ids].present?
        attach_tags(params[:tag_ids]) if params[:tag_ids].present?
        
        # Initialize analytics tracking
        initialize_campaign_analytics
        
        # Log campaign creation
        audit_log("Campaign '#{@campaign.name}' created")
        
        Result.success(@campaign)
      else
        @errors.merge!(@campaign.errors)
        Result.failure(@errors)
      end
    end
  rescue => e
    Rails.logger.error "Campaign creation failed: #{e.message}"
    @errors.add(:base, "Failed to create campaign: #{e.message}")
    Result.failure(@errors)
  end

  # Schedule a campaign for later sending
  def schedule(datetime, timezone = 'UTC')
    return Result.failure("Campaign must be in draft status") unless @campaign.draft?
    return Result.failure("Invalid scheduling time") if datetime.blank? || datetime <= Time.current

    # Convert timezone if provided
    scheduled_time = timezone != 'UTC' ? 
      Time.zone.parse(datetime.to_s).in_time_zone(timezone).utc : 
      datetime

    if @campaign.update(status: 'scheduled', scheduled_at: scheduled_time)
      # Schedule the background job
      CampaignSenderJob.set(wait_until: scheduled_time).perform_later(@campaign.id)
      
      audit_log("Campaign '#{@campaign.name}' scheduled for #{scheduled_time}")
      Result.success(@campaign)
    else
      Result.failure(@campaign.errors)
    end
  end

  # Send campaign immediately
  def send_now
    return Result.failure("Campaign cannot be sent") unless @campaign.can_be_sent?
    return Result.failure("No contacts selected") if @campaign.contacts.empty?

    @campaign.update!(status: 'sending')
    
    # Enqueue immediate sending
    CampaignSenderJob.perform_later(@campaign.id)
    
    audit_log("Campaign '#{@campaign.name}' sent immediately")
    Result.success(@campaign)
  rescue => e
    Rails.logger.error "Campaign sending failed: #{e.message}"
    @campaign.update(status: 'draft') if @campaign&.sending?
    Result.failure("Failed to send campaign: #{e.message}")
  end

  # Duplicate campaign with smart defaults
  def duplicate(new_name = nil)
    new_campaign = @campaign.dup
    new_campaign.name = new_name || "#{@campaign.name} (Copy)"
    new_campaign.status = 'draft'
    new_campaign.scheduled_at = nil
    new_campaign.sent_at = nil
    new_campaign.open_rate = nil
    new_campaign.click_rate = nil
    new_campaign.user = Current.user if Current.user

    ApplicationRecord.transaction do
      if new_campaign.save
        # Copy associations
        copy_campaign_contacts(new_campaign)
        copy_campaign_tags(new_campaign)
        
        audit_log("Campaign '#{@campaign.name}' duplicated as '#{new_campaign.name}'")
        Result.success(new_campaign)
      else
        Result.failure(new_campaign.errors)
      end
    end
  rescue => e
    Rails.logger.error "Campaign duplication failed: #{e.message}"
    Result.failure("Failed to duplicate campaign: #{e.message}")
  end

  # Pause an active campaign
  def pause
    return Result.failure("Only sending campaigns can be paused") unless @campaign.sending?

    if @campaign.update(status: 'paused')
      # Cancel any pending jobs
      cancel_pending_jobs
      
      audit_log("Campaign '#{@campaign.name}' paused")
      Result.success(@campaign)
    else
      Result.failure(@campaign.errors)
    end
  end

  # Resume a paused campaign
  def resume
    return Result.failure("Only paused campaigns can be resumed") unless @campaign.paused?

    if @campaign.update(status: 'sending')
      # Re-enqueue remaining sends
      enqueue_remaining_sends
      
      audit_log("Campaign '#{@campaign.name}' resumed")
      Result.success(@campaign)
    else
      Result.failure(@campaign.errors)
    end
  end

  # Get comprehensive campaign statistics
  def detailed_stats
    return {} unless @campaign.sent?

    {
      basic_stats: basic_campaign_stats,
      engagement_timeline: engagement_timeline,
      geographic_distribution: geographic_distribution,
      device_breakdown: device_breakdown,
      top_performing_links: top_performing_links
    }
  end

  # A/B test campaign setup
  def setup_ab_test(variant_params)
    return Result.failure("Campaign must be in draft status") unless @campaign.draft?

    ApplicationRecord.transaction do
      variant_campaign = @campaign.dup
      variant_campaign.name = "#{@campaign.name} (Variant B)"
      variant_campaign.assign_attributes(variant_params)
      
      if variant_campaign.save
        # Mark both as A/B test campaigns
        @campaign.update!(ab_test_group: 'A', ab_test_parent_id: @campaign.id)
        variant_campaign.update!(ab_test_group: 'B', ab_test_parent_id: @campaign.id)
        
        audit_log("A/B test setup for campaign '#{@campaign.name}'")
        Result.success(variant_campaign)
      else
        Result.failure(variant_campaign.errors)
      end
    end
  rescue => e
    Rails.logger.error "A/B test setup failed: #{e.message}"
    Result.failure("Failed to setup A/B test: #{e.message}")
  end

  private

  def attach_contacts(contact_ids)
    contacts = @account.contacts.where(id: contact_ids)
    @campaign.contacts = contacts
  end

  def attach_tags(tag_ids)
    tags = @account.tags.where(id: tag_ids)
    @campaign.tags = tags
  end

  def initialize_campaign_analytics
    # Create initial analytics record
    # This could be expanded to include more detailed tracking setup
  end

  def copy_campaign_contacts(new_campaign)
    @campaign.campaign_contacts.find_each do |cc|
      new_campaign.campaign_contacts.create!(
        contact: cc.contact,
        status: 'pending'
      )
    end
  end

  def copy_campaign_tags(new_campaign)
    @campaign.campaign_tags.find_each do |ct|
      new_campaign.campaign_tags.create!(tag: ct.tag)
    end
  end

  def basic_campaign_stats
    {
      total_sent: @campaign.campaign_contacts.sent.count,
      total_delivered: @campaign.campaign_contacts.delivered.count,
      total_opened: @campaign.campaign_contacts.opened.count,
      total_clicked: @campaign.campaign_contacts.clicked.count,
      total_bounced: @campaign.campaign_contacts.bounced.count,
      total_unsubscribed: @campaign.campaign_contacts.unsubscribed.count,
      open_rate: @campaign.open_rate || 0,
      click_rate: @campaign.click_rate || 0,
      delivery_rate: calculate_delivery_rate,
      bounce_rate: calculate_bounce_rate
    }
  end

  def engagement_timeline
    # Group engagements by hour/day for timeline visualization
    @campaign.campaign_contacts
             .where.not(opened_at: nil)
             .group_by_hour(:opened_at, last: 7.days)
             .count
  end

  def geographic_distribution
    # This would require IP tracking or contact location data
    # Placeholder for now
    {}
  end

  def device_breakdown
    # This would require user-agent tracking
    # Placeholder for now
    {}
  end

  def top_performing_links
    # This would require link click tracking
    # Placeholder for now
    []
  end

  def calculate_delivery_rate
    total_sent = @campaign.campaign_contacts.sent.count
    return 0 if total_sent.zero?
    
    delivered = @campaign.campaign_contacts.delivered.count
    ((delivered.to_f / total_sent) * 100).round(2)
  end

  def calculate_bounce_rate
    total_sent = @campaign.campaign_contacts.sent.count
    return 0 if total_sent.zero?
    
    bounced = @campaign.campaign_contacts.bounced.count
    ((bounced.to_f / total_sent) * 100).round(2)
  end

  def cancel_pending_jobs
    # Cancel any scheduled jobs for this campaign
    # This would require integration with job queue system
  end

  def enqueue_remaining_sends
    # Re-enqueue sends for contacts that haven't been sent to yet
    pending_contacts = @campaign.campaign_contacts.pending
    pending_contacts.find_each do |cc|
      CampaignContactSenderJob.perform_later(cc.id)
    end
  end

  def audit_log(message)
    @account.audit_logs.create!(
      user: Current.user,
      action: 'campaign_operation',
      details: message,
      resource_type: 'Campaign',
      resource_id: @campaign.id
    )
  rescue => e
    Rails.logger.warn "Failed to create audit log: #{e.message}"
  end

  # Result class for consistent return values
  class Result
    attr_reader :data, :errors, :success

    def initialize(success:, data: nil, errors: nil)
      @success = success
      @data = data
      @errors = errors
    end

    def self.success(data = nil)
      new(success: true, data: data)
    end

    def self.failure(errors)
      new(success: false, errors: errors)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
