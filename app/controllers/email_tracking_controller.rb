class EmailTrackingController < ApplicationController
  skip_before_action :authenticate_user!, only: [:open, :click, :unsubscribe]
  skip_before_action :set_current_account, only: [:open, :click, :unsubscribe]
  skip_before_action :verify_authenticity_token, only: [:open, :click, :unsubscribe]

  def open
    campaign_contact = find_campaign_contact_by_token(params[:token])
    
    if campaign_contact
      campaign_contact.mark_as_opened!
      Rails.logger.info "Email opened: Campaign #{campaign_contact.campaign_id}, Contact #{campaign_contact.contact_id}"
      
      # Broadcast real-time update
      CampaignBroadcastService.broadcast_campaign_update(campaign_contact.campaign)
    end

    # Return 1x1 transparent pixel
    send_data(
      Base64.decode64("R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7"),
      type: 'image/gif',
      disposition: 'inline'
    )
  end

  def click
    campaign_contact = find_campaign_contact_by_token(params[:token])
    redirect_url = params[:url] || root_url
    
    if campaign_contact
      campaign_contact.mark_as_clicked!
      Rails.logger.info "Email clicked: Campaign #{campaign_contact.campaign_id}, Contact #{campaign_contact.contact_id}"
      
      # Broadcast real-time update
      CampaignBroadcastService.broadcast_campaign_update(campaign_contact.campaign)
    end

    redirect_to redirect_url, allow_other_host: true
  end

  def unsubscribe
    contact = find_contact_by_unsubscribe_token(params[:token])
    
    if contact
      contact.unsubscribe!
      Rails.logger.info "Contact unsubscribed: #{contact.email}"
      
      @contact = contact
      render :unsubscribe_success
    else
      Rails.logger.warn "Invalid unsubscribe token: #{params[:token]}"
      render :unsubscribe_error, status: :not_found
    end
  end

  private

  def find_campaign_contact_by_token(token)
    return nil unless token.present?
    
    # For now, use a simple approach. In production, you'd want more sophisticated token validation
    # This assumes the token was generated using the same method as in the job
    CampaignContact.joins(:campaign, :contact)
                   .where(campaigns: { status: 'sent' })
                   .find { |cc| token_matches?(token, cc) }
  end

  def find_contact_by_unsubscribe_token(token)
    return nil unless token.present?
    
    Contact.all.find { |contact| unsubscribe_token_matches?(token, contact) }
  end

  def token_matches?(token, campaign_contact)
    expected_token = Digest::SHA256.hexdigest(
      "#{campaign_contact.id}-#{campaign_contact.campaign_id}-#{campaign_contact.contact_id}-#{Rails.application.secret_key_base}"
    )
    ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
  end

  def unsubscribe_token_matches?(token, contact)
    expected_token = Digest::SHA256.hexdigest(
      "#{contact.id}-#{contact.email}-#{Rails.application.secret_key_base}"
    )
    ActiveSupport::SecurityUtils.secure_compare(token, expected_token)
  end
end
