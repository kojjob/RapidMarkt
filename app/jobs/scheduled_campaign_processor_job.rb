class ScheduledCampaignProcessorJob < ApplicationJob
  queue_as :scheduled_campaigns

  def perform(campaign_id = nil)
    if campaign_id.present?
      # Process a specific scheduled campaign
      process_single_campaign(campaign_id)
    else
      # Process all ready campaigns (for periodic processing)
      process_all_ready_campaigns
    end
  end
  
  private
  
  def process_single_campaign(campaign_id)
    campaign = Campaign.find(campaign_id)
    
    unless campaign.scheduled?
      Rails.logger.warn "Campaign #{campaign_id} is not in scheduled status, skipping"
      return
    end
    
    unless campaign.ready_to_send?
      Rails.logger.warn "Campaign #{campaign_id} is not ready to send yet, skipping"
      return
    end
    
    Rails.logger.info "Processing scheduled campaign: #{campaign.id} - #{campaign.name}"
    
    begin
      # Queue the campaign for sending
      CampaignSenderJob.perform_later(campaign.id)
      
      # Update status to prevent duplicate processing
      campaign.update!(status: 'sending')
      
    rescue => e
      Rails.logger.error "Failed to queue scheduled campaign #{campaign.id}: #{e.message}"
      
      # Optionally notify admins or retry later
      # CampaignErrorNotificationJob.perform_later(campaign.id, e.message)
    end
  end
  
  def process_all_ready_campaigns
    # Find campaigns that are scheduled and ready to send
    ready_campaigns = Campaign.ready_to_send
    
    Rails.logger.info "Processing #{ready_campaigns.count} scheduled campaigns"
    
    ready_campaigns.find_each do |campaign|
      process_single_campaign(campaign.id)
    end
  end
end
