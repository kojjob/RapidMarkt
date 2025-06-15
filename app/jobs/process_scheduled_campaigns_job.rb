# frozen_string_literal: true

# Job to process scheduled campaigns
class ProcessScheduledCampaignsJob < ApplicationJob
  include Auditable

  queue_as :campaigns

  retry_on StandardError, attempts: 2

  def perform
    Rails.logger.info "Processing scheduled campaigns at #{Time.current}"

    # Find campaigns ready to send
    ready_campaigns = Campaign.ready_to_send.includes(:account, :user, :template)

    Rails.logger.info "Found #{ready_campaigns.count} campaigns ready to send"

    ready_campaigns.find_each do |campaign|
      begin
        # Validate campaign can still be sent
        next unless campaign.can_be_sent?

        # Enqueue campaign sending job
        CampaignSenderJob.perform_later(campaign.id)

        Rails.logger.info "Queued campaign #{campaign.id} for sending"

      rescue => error
        Rails.logger.error "Failed to queue campaign #{campaign.id}: #{error.message}"

        campaign.update!(
          status: "failed",
          error_message: error.message,
          failed_at: Time.current
        )
      end
    end

    Rails.logger.info "Finished processing scheduled campaigns"
  end
end
