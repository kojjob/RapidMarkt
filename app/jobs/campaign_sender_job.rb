class CampaignSenderJob < ApplicationJob
  queue_as :default
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  discard_on ActiveRecord::RecordNotFound

  def perform(campaign_id, batch_size: 100)
    campaign = Campaign.find(campaign_id)

    # Validate campaign can be sent
    unless campaign.can_be_sent?
      Rails.logger.error "Campaign #{campaign.id} cannot be sent. Status: #{campaign.status}"
      return
    end

    # Update campaign status and broadcast to dashboard
    campaign.update!(status: "sending")
    CampaignBroadcastService.broadcast_campaign_update(campaign)

    begin
      # Get contacts to send to
      contacts = get_campaign_contacts(campaign)
      total_contacts = contacts.count

      Rails.logger.info "Starting campaign #{campaign.id} send to #{total_contacts} contacts"

      # Process contacts in batches to avoid memory issues
      sent_count = 0
      failed_count = 0

      contacts.find_in_batches(batch_size: batch_size) do |contact_batch|
        contact_batch.each do |contact|
          begin
            send_email_to_contact(campaign, contact)
            sent_count += 1
          rescue => e
            Rails.logger.error "Failed to send email to #{contact.email}: #{e.message}"
            failed_count += 1
          end
        end

        # Update progress and broadcast to dashboard
        progress = (sent_count.to_f / total_contacts * 100).round(1)
        Rails.logger.info "Campaign #{campaign.id} progress: #{sent_count}/#{total_contacts} (#{progress}%)"
        
        # Broadcast progress update
        CampaignBroadcastService.broadcast_campaign_progress(campaign, {
          sent_count: sent_count,
          total_count: total_contacts,
          progress: progress,
          failed_count: failed_count
        })
      end

      # Update campaign as sent
      campaign.update!(
        status: "sent",
        sent_at: Time.current
      )

      # Calculate and update rates
      campaign.calculate_rates

      Rails.logger.info "Campaign #{campaign.id} completed: #{sent_count} sent, #{failed_count} failed"
      
      # Final broadcast
      CampaignBroadcastService.broadcast_campaign_complete(campaign, {
        sent_count: sent_count,
        failed_count: failed_count,
        total_count: total_contacts
      })

    rescue => e
      Rails.logger.error "Critical failure sending campaign #{campaign.id}: #{e.message}"
      campaign.update!(status: "draft") # Revert to draft on failure
      CampaignBroadcastService.broadcast_campaign_error(campaign, e.message)
      raise e
    end
  end

  private

  def get_campaign_contacts(campaign)
    # Start with subscribed contacts for the account
    contacts = campaign.account.contacts.where(status: "subscribed")

    # Filter by recipient type
    case campaign.recipient_type
    when "all"
      # Send to all contacts (subscribed and unsubscribed)
      contacts = campaign.account.contacts
    when "subscribed"
      # Already filtered to subscribed contacts above
      contacts
    when "tags"
      # Filter by selected tags
      if campaign.tags.any?
        tag_ids = campaign.tags.pluck(:id)
        contacts = contacts.joins(:contact_tags).where(contact_tags: { tag_id: tag_ids }).distinct
      else
        # No tags selected, return empty collection
        contacts = contacts.none
      end
    else
      # Default to subscribed contacts
      contacts
    end

    contacts
  end

  def send_email_to_contact(campaign, contact)
    # Create or find campaign contact record
    campaign_contact = CampaignContact.find_or_create_by(
      campaign: campaign,
      contact: contact
    ) do |cc|
      cc.sent_at = Time.current
    end

    # Skip if already sent
    if campaign_contact.sent_at.present? && campaign_contact.persisted?
      Rails.logger.debug "Skipping #{contact.email} - already sent"
      return
    end

    # Render email content with contact variables
    rendered_content = render_email_content(campaign, contact)
    rendered_subject = render_email_subject(campaign, contact)

    # Generate tracking parameters
    tracking_params = generate_tracking_params(campaign_contact)

    # Send email using ActionMailer with tracking
    CampaignMailer.send_campaign(
      campaign: campaign,
      contact: contact,
      campaign_contact: campaign_contact,
      subject: rendered_subject,
      content: rendered_content,
      tracking_params: tracking_params
    ).deliver_now

    # Update sent timestamp
    campaign_contact.update!(sent_at: Time.current)

    Rails.logger.debug "Email sent to #{contact.email} for campaign #{campaign.id}"

  rescue => e
    # Mark as failed but don't break the batch
    if defined?(campaign_contact) && campaign_contact
      campaign_contact.update(
        bounced_at: Time.current,
        failure_reason: e.message.truncate(255)
      )
    end
    
    Rails.logger.error "Failed to send email to #{contact.email} for campaign #{campaign.id}: #{e.message}"
    raise e # Re-raise to be caught by caller for counting
  end

  def render_email_content(campaign, contact)
    content = campaign.template&.body || campaign.content || ""

    # Replace variables with contact data
    content.gsub(/\{\{(\w+)\}\}/) do |match|
      variable_name = $1
      get_variable_value(variable_name, contact, campaign)
    end
  end

  def render_email_subject(campaign, contact)
    subject = campaign.subject || ""

    # Replace variables with contact data
    subject.gsub(/\{\{(\w+)\}\}/) do |match|
      variable_name = $1
      get_variable_value(variable_name, contact, campaign)
    end
  end

  def generate_tracking_params(campaign_contact)
    # Generate unique tracking token for this campaign-contact combination
    token = Digest::SHA256.hexdigest("#{campaign_contact.id}-#{campaign_contact.campaign_id}-#{campaign_contact.contact_id}-#{Rails.application.secret_key_base}")
    
    {
      open_token: token,
      click_token: token,
      unsubscribe_token: token
    }
  end

  def get_variable_value(variable_name, contact, campaign)
    case variable_name.downcase
    when "first_name"
      contact.first_name || "there"
    when "last_name"
      contact.last_name || ""
    when "full_name"
      contact.full_name || "there"
    when "email"
      contact.email
    when "company_name", "account_name"
      campaign.account.name
    when "date"
      Date.current.strftime("%B %d, %Y")
    when "time"
      Time.current.strftime("%I:%M %p")
    when "datetime"
      Time.current.strftime("%B %d, %Y at %I:%M %p")
    when "campaign_name"
      campaign.name
    when "unsubscribe_url"
      # Generate unsubscribe URL with token
      Rails.application.routes.url_helpers.unsubscribe_url(
        token: generate_unsubscribe_token(contact),
        host: Rails.application.config.action_mailer.default_url_options[:host] || "localhost:3000"
      )
    else
      "{{#{variable_name}}}" # Keep original if not found
    end
  end

  def generate_unsubscribe_token(contact)
    # Generate secure unsubscribe token
    Digest::SHA256.hexdigest("#{contact.id}-#{contact.email}-#{Rails.application.secret_key_base}")
  end
end
