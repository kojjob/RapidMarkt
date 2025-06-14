class CampaignSenderJob < ApplicationJob
  queue_as :default

  def perform(campaign_id)
    campaign = Campaign.find(campaign_id)
    
    # Validate campaign can be sent
    unless campaign.can_be_sent?
      Rails.logger.error "Campaign #{campaign.id} cannot be sent. Status: #{campaign.status}"
      return
    end

    # Update campaign status
    campaign.update!(status: 'sending')
    
    begin
      # Get contacts to send to
      contacts = get_campaign_contacts(campaign)
      
      Rails.logger.info "Sending campaign #{campaign.id} to #{contacts.count} contacts"
      
      # Send emails to each contact
      contacts.each do |contact|
        send_email_to_contact(campaign, contact)
      end
      
      # Update campaign as sent
      campaign.update!(
        status: 'sent',
        sent_at: Time.current
      )
      
      Rails.logger.info "Campaign #{campaign.id} sent successfully to #{contacts.count} contacts"
      
    rescue => e
      Rails.logger.error "Failed to send campaign #{campaign.id}: #{e.message}"
      campaign.update!(status: 'draft') # Revert to draft on failure
      raise e
    end
  end

  private

  def get_campaign_contacts(campaign)
    # Start with subscribed contacts for the account
    contacts = campaign.account.contacts.where(status: 'subscribed')
    
    # Filter by recipient type
    case campaign.recipient_type
    when 'all'
      # Send to all contacts (subscribed and unsubscribed)
      contacts = campaign.account.contacts
    when 'subscribed'
      # Already filtered to subscribed contacts above
      contacts
    when 'tags'
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
    # Create campaign contact record
    campaign_contact = CampaignContact.create!(
      campaign: campaign,
      contact: contact,
      sent_at: Time.current
    )
    
    # Render email content with contact variables
    rendered_content = render_email_content(campaign, contact)
    rendered_subject = render_email_subject(campaign, contact)
    
    # Send email using ActionMailer
    CampaignMailer.send_campaign(
      campaign: campaign,
      contact: contact,
      subject: rendered_subject,
      content: rendered_content
    ).deliver_now
    
    Rails.logger.debug "Email sent to #{contact.email} for campaign #{campaign.id}"
    
  rescue => e
    Rails.logger.error "Failed to send email to #{contact.email} for campaign #{campaign.id}: #{e.message}"
    # Don't re-raise to continue sending to other contacts
  end

  def render_email_content(campaign, contact)
    content = campaign.template&.body || campaign.body || ''
    
    # Replace variables with contact data
    content.gsub(/\{\{(\w+)\}\}/) do |match|
      variable_name = $1
      get_variable_value(variable_name, contact, campaign)
    end
  end

  def render_email_subject(campaign, contact)
    subject = campaign.subject || ''
    
    # Replace variables with contact data
    subject.gsub(/\{\{(\w+)\}\}/) do |match|
      variable_name = $1
      get_variable_value(variable_name, contact, campaign)
    end
  end

  def get_variable_value(variable_name, contact, campaign)
    case variable_name.downcase
    when 'first_name'
      contact.first_name || 'there'
    when 'last_name'
      contact.last_name || ''
    when 'email'
      contact.email
    when 'company_name'
      campaign.account.name
    when 'date'
      Date.current.strftime('%B %d, %Y')
    when 'unsubscribe_url'
      # This would be a real unsubscribe URL in production
      "#{Rails.application.routes.url_helpers.root_url}unsubscribe?token=#{contact.id}"
    else
      "{{#{variable_name}}}" # Keep original if not found
    end
  end
end