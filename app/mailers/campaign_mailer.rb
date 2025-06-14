class CampaignMailer < ApplicationMailer
  default from: "noreply@rapidmarkt.com"

  def send_campaign(campaign:, contact:, campaign_contact:, subject:, content:, tracking_params: {})
    @campaign = campaign
    @contact = contact
    @campaign_contact = campaign_contact
    @content = content
    @account = campaign.account

    # Set tracking parameters
    @tracking_params = tracking_params.merge({
      campaign_id: campaign.id,
      contact_id: contact.id,
      campaign_contact_id: campaign_contact.id
    })

    # Add tracking pixels and unsubscribe links to content
    @content_with_tracking = add_tracking_to_content(@content, @tracking_params)

    # Use campaign's from email if set, otherwise use default
    from_email = campaign.from_email.present? ? campaign.from_email : "noreply@rapidmarkt.com"
    from_name = campaign.from_name.present? ? campaign.from_name : @account.name

    mail(
      to: contact.email,
      subject: subject,
      from: "#{from_name} <#{from_email}>",
      reply_to: campaign.reply_to.present? ? campaign.reply_to : from_email,
      'X-Campaign-ID' => campaign.id.to_s,
      'X-Contact-ID' => contact.id.to_s
    )
  end

  private

  def add_tracking_to_content(content, tracking_params)
    # Add tracking pixel for opens
    tracking_pixel = tracking_pixel_html(tracking_params[:open_token])
    
    # Add unsubscribe link if not already present
    unsubscribe_link = unsubscribe_link_html(tracking_params[:unsubscribe_token])
    
    # Inject tracking into HTML content
    if content.include?('</body>')
      # Insert before closing body tag
      content.gsub('</body>', "#{tracking_pixel}#{unsubscribe_link}</body>")
    else
      # Append to end if no body tag
      "#{content}#{tracking_pixel}#{unsubscribe_link}"
    end
  end

  def tracking_pixel_html(token)
    return '' unless token
    
    tracking_url = Rails.application.routes.url_helpers.track_email_open_url(
      token: token,
      host: Rails.application.config.action_mailer.default_url_options[:host] || "localhost:3000"
    )
    
    %{<img src="#{tracking_url}" width="1" height="1" style="display:none;" alt="" />}
  end

  def unsubscribe_link_html(token)
    return '' unless token
    
    unsubscribe_url = Rails.application.routes.url_helpers.unsubscribe_url(
      token: token,
      host: Rails.application.config.action_mailer.default_url_options[:host] || "localhost:3000"
    )
    
    %{
      <div style="font-size: 12px; color: #666; text-align: center; margin-top: 20px; border-top: 1px solid #eee; padding-top: 10px;">
        <p>You received this email because you're subscribed to our newsletter.</p>
        <p><a href="#{unsubscribe_url}" style="color: #666;">Unsubscribe</a> from future emails.</p>
      </div>
    }
  end

  def generate_tracking_token(campaign, contact)
    # Generate a secure token for tracking opens/clicks
    Digest::SHA256.hexdigest("#{campaign.id}-#{contact.id}-#{Rails.application.secret_key_base}")
  end
end
