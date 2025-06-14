class ScheduledCampaignProcessorJob < ApplicationJob
  queue_as :scheduled_campaigns

  def perform
    # Find campaigns that are scheduled and ready to send
    ready_campaigns = Campaign.ready_to_send
    
    Rails.logger.info "Processing #{ready_campaigns.count} scheduled campaigns"
    
    ready_campaigns.find_each do |campaign|
      begin
        Rails.logger.info "Queueing scheduled campaign: #{campaign.id} - #{campaign.name}"
        
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
  end
end
