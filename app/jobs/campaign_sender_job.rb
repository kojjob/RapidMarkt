class CampaignSenderJob < ApplicationJob
  queue_as QueuePriorities::CAMPAIGNS
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Net::TimeoutError, wait: 1.minute, attempts: 5
  discard_on ActiveRecord::RecordNotFound
  
  # Rate limiting to prevent overwhelming email services
  rate_limit to: 200, within: 1.minute, by: :account_id

  def perform(campaign_id, options = {})
    campaign = Campaign.find(campaign_id)
    
    # Check if this is an automation campaign
    is_automation = options[:automation] || campaign.metadata&.dig('is_automation')

    # Validate campaign can be sent
    unless campaign.can_be_sent?
      Rails.logger.error "Campaign #{campaign.id} cannot be sent. Status: #{campaign.status}"
      return
    end

    # Update campaign status
    campaign.update!(
      status: "sending",
      sending_started_at: Time.current
    )

    begin
      # Get contacts to send to
      contacts = get_campaign_contacts(campaign)
      total_contacts = contacts.count

      Rails.logger.info "Sending campaign #{campaign.id} to #{total_contacts} contacts"

      # Process contacts in batches for better memory management
      sent_count = 0
      failed_count = 0
      
      contacts.find_in_batches(batch_size: 100) do |contact_batch|
        contact_batch.each do |contact|
          result = send_email_to_contact(campaign, contact)
          if result[:success]
            sent_count += 1
          else
            failed_count += 1
          end
          
          # Update progress periodically
          if (sent_count + failed_count) % 50 == 0
            update_campaign_progress(campaign, sent_count, failed_count, total_contacts)
          end
        end
      end

      # Final campaign update
      campaign.update!(
        status: "sent",
        sent_at: Time.current,
        sent_count: sent_count,
        failed_count: failed_count,
        metadata: campaign.metadata.merge({
          sending_completed_at: Time.current,
          total_contacts: total_contacts,
          success_rate: (sent_count.to_f / total_contacts * 100).round(2)
        })
      )

      Rails.logger.info "Campaign #{campaign.id} completed: #{sent_count} sent, #{failed_count} failed"
      
      # Trigger post-send automation if not already an automation
      unless is_automation
        trigger_post_send_automations(campaign)
      end

    rescue => e
      Rails.logger.error "Failed to send campaign #{campaign.id}: #{e.message}"
      campaign.update!(
        status: "failed",
        error_message: e.message,
        failed_at: Time.current
      )
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
    begin
      # Create campaign contact record
      campaign_contact = CampaignContact.create!(
        campaign: campaign,
        contact: contact,
        sent_at: Time.current,
        status: 'sending'
      )

      # Render email content with contact variables
      rendered_content = render_email_content(campaign, contact)
      rendered_subject = render_email_subject(campaign, contact)

      # Send email using ActionMailer or external service
      delivery_result = deliver_email(campaign, contact, rendered_subject, rendered_content)
      
      if delivery_result[:success]
        # Update campaign contact status
        campaign_contact.update!(
          status: 'sent',
          delivered_at: Time.current,
          message_id: delivery_result[:message_id]
        )
        
        # Log contact activity
        ContactActivityLog.create!(
          contact: contact,
          account: contact.account,
          activity_type: 'email_sent',
          metadata: {
            campaign_id: campaign.id,
            subject: rendered_subject,
            message_id: delivery_result[:message_id]
          }
        )
        
        # Update contact engagement tracking
        contact.touch(:last_email_sent_at)
        
        Rails.logger.debug "Email sent to #{contact.email} for campaign #{campaign.id}"
        { success: true, message_id: delivery_result[:message_id] }
      else
        # Update campaign contact with failure
        campaign_contact.update!(
          status: 'failed',
          error_message: delivery_result[:error]
        )
        
        Rails.logger.error "Failed to deliver email to #{contact.email}: #{delivery_result[:error]}"
        { success: false, error: delivery_result[:error] }
      end

    rescue => e
      Rails.logger.error "Failed to send email to #{contact.email} for campaign #{campaign.id}: #{e.message}"
      
      # Update campaign contact if it was created
      campaign_contact&.update!(
        status: 'failed',
        error_message: e.message
      )
      
      { success: false, error: e.message }
    end
  end
  
  def deliver_email(campaign, contact, subject, content)
    # Use ActionMailer for now - this could be enhanced to use external services
    begin
      CampaignMailer.send_campaign(
        campaign: campaign,
        contact: contact,
        subject: subject,
        content: content
      ).deliver_now
      
      { success: true, message_id: SecureRandom.uuid }
    rescue => e
      { success: false, error: e.message }
    end
  end
  
  def update_campaign_progress(campaign, sent_count, failed_count, total_contacts)
    progress_percentage = ((sent_count + failed_count).to_f / total_contacts * 100).round(2)
    
    campaign.update!(
      metadata: campaign.metadata.merge({
        progress_percentage: progress_percentage,
        sent_count: sent_count,
        failed_count: failed_count,
        last_progress_update: Time.current
      })
    )
  end
  
  def trigger_post_send_automations(campaign)
    # Find automations triggered by campaign sends
    automations = campaign.account.email_automations
                          .where(trigger_type: 'campaign_sent')
                          .where(active: true)
    
    automations.each do |automation|
      # Check if automation conditions match this campaign
      trigger_conditions = automation.trigger_conditions || {}
      
      # Check campaign tags
      if trigger_conditions['campaign_tags'].present?
        required_tags = trigger_conditions['campaign_tags']
        campaign_tag_names = campaign.tags.pluck(:name)
        
        next unless (required_tags & campaign_tag_names).any?
      end
      
      # Check campaign type
      if trigger_conditions['campaign_type'].present?
        next unless campaign.send_type == trigger_conditions['campaign_type']
      end
      
      # Enroll campaign contacts in automation
      campaign.contacts.where(status: 'subscribed').find_each do |contact|
        # Skip if already enrolled
        next if automation.automation_enrollments.exists?(contact: contact)
        
        enrollment = AutomationEnrollment.create!(
          email_automation: automation,
          contact: contact,
          status: 'active',
          enrolled_at: Time.current,
          trigger_data: {
            campaign_id: campaign.id,
            campaign_name: campaign.name,
            enrolled_via: 'post_campaign_send'
          }
        )
        
        # Start automation
        first_step = automation.automation_steps.order(:step_order).first
        if first_step
          execution = AutomationExecution.create!(
            automation_enrollment: enrollment,
            automation_step: first_step,
            status: 'pending',
            scheduled_at: Time.current
          )
          
          ProcessAutomationExecutionJob.perform_later(execution.id)
        end
      end
    end
  end

  def render_email_content(campaign, contact)
    content = campaign.template&.body || campaign.body || ""

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

  def get_variable_value(variable_name, contact, campaign)
    case variable_name.downcase
    when "first_name"
      contact.first_name || "there"
    when "last_name"
      contact.last_name || ""
    when "full_name"
      [contact.first_name, contact.last_name].compact.join(" ").presence || "there"
    when "email"
      contact.email
    when "company_name", "account_name"
      campaign.account.name
    when "date"
      Date.current.strftime("%B %d, %Y")
    when "time"
      Time.current.strftime("%I:%M %p")
    when "year"
      Date.current.year.to_s
    when "month"
      Date.current.strftime("%B")
    when "day"
      Date.current.day.to_s
    when "campaign_name"
      campaign.name
    when "sender_name"
      campaign.user.full_name || campaign.account.name
    when "unsubscribe_url"
      # This would be a real unsubscribe URL in production
      Rails.application.routes.url_helpers.unsubscribe_url(
        token: contact.unsubscribe_token,
        host: Rails.application.config.action_mailer.default_url_options[:host]
      )
    when "preferences_url"
      Rails.application.routes.url_helpers.preferences_url(
        token: contact.preferences_token,
        host: Rails.application.config.action_mailer.default_url_options[:host]
      )
    else
      # Check if it's a custom contact field
      if contact.respond_to?(variable_name.downcase)
        contact.send(variable_name.downcase)
      elsif contact.custom_fields&.key?(variable_name)
        contact.custom_fields[variable_name]
      else
        "{{#{variable_name}}}" # Keep original if not found
      end
    end
  end
  
  def account_id
    # Extract account ID for rate limiting
    campaign = Campaign.find(arguments.first)
    campaign.account_id
  rescue
    nil
  end
end
