class CampaignMailer < ApplicationMailer
  default from: 'noreply@rapidmarkt.com'

  def send_campaign(campaign:, contact:, subject:, content:)
    @campaign = campaign
    @contact = contact
    @content = content
    @account = campaign.account
    
    # Set tracking parameters
    @tracking_params = {
      campaign_id: campaign.id,
      contact_id: contact.id,
      token: generate_tracking_token(campaign, contact)
    }
    
    mail(
      to: contact.email,
      subject: subject,
      from: "#{@account.name} <noreply@rapidmarkt.com>",
      reply_to: "noreply@rapidmarkt.com"
    )
  end

  private

  def generate_tracking_token(campaign, contact)
    # Generate a secure token for tracking opens/clicks
    Digest::SHA256.hexdigest("#{campaign.id}-#{contact.id}-#{Rails.application.secret_key_base}")
  end
end