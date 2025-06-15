# frozen_string_literal: true

# Job to process individual automation step executions
# Handles email sending, wait periods, conditions, and actions
class ProcessAutomationExecutionJob < ApplicationJob
  queue_as QueuePriorities::AUTOMATION
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Net::TimeoutError, wait: 30.seconds, attempts: 5
  discard_on ActiveRecord::RecordNotFound
  
  # Simple rate limiting (no external dependencies)
  before_perform do |job|
    account_id = job.account_id
    if account_id
      rate_limit_key = "automation_rate_limit:#{account_id}:#{Time.current.to_i / 60}" # per minute
      current_count = Rails.cache.read(rate_limit_key) || 0
      
      if current_count >= 100
        job.retry_job(wait: 1.minute)
        return false
      end
      
      Rails.cache.write(rate_limit_key, current_count + 1, expires_in: 2.minutes)
    end
  end
  
  def perform(execution_id)
    execution = AutomationExecution.find(execution_id)
    
    # Skip if already processed or failed too many times
    return if execution.completed? || execution.failed_permanently?
    
    # Update execution status
    execution.update!(
      status: 'processing',
      started_at: Time.current,
      attempts: execution.attempts + 1
    )
    
    begin
      result = process_automation_step(execution)
      
      if result.success?
        handle_successful_execution(execution, result)
      else
        handle_failed_execution(execution, result.error)
      end
      
    rescue => error
      handle_exception(execution, error)
    end
  end
  
  private
  
  def process_automation_step(execution)
    step = execution.automation_step
    enrollment = execution.automation_enrollment
    contact = enrollment.contact
    
    Rails.logger.info "Processing automation step: #{step.step_type} for contact: #{contact.id}"
    
    case step.step_type
    when 'email'
      send_automation_email(step, contact, enrollment)
    when 'wait'
      process_wait_step(step, execution)
    when 'condition'
      evaluate_condition(step, contact, enrollment)
    when 'tag_add'
      add_tags_to_contact(step, contact)
    when 'tag_remove'
      remove_tags_from_contact(step, contact)
    when 'list_add'
      add_contact_to_list(step, contact)
    when 'list_remove'
      remove_contact_from_list(step, contact)
    when 'update_field'
      update_contact_field(step, contact)
    when 'webhook'
      trigger_webhook(step, contact, enrollment)
    else
      Result.failure("Unknown step type: #{step.step_type}")
    end
  end
  
  def send_automation_email(step, contact, enrollment)
    # Get email template from step configuration
    template_id = step.configuration['template_id']
    template = Template.find_by(id: template_id)
    
    return Result.failure("Template not found: #{template_id}") unless template
    
    # Personalize email content
    subject = personalize_content(template.subject, contact)
    body = personalize_content(template.body, contact)
    
    # Create campaign for this automation email
    campaign = create_automation_campaign(template, contact, subject, body, enrollment)
    
    # Send email using existing email service
    email_result = EmailService.send_email(
      to: contact.email,
      subject: subject,
      body: body,
      from: step.configuration.dig('from_email') || enrollment.email_automation.account.default_from_email,
      campaign: campaign
    )
    
    if email_result.success?
      # Log email activity
      ContactActivityLog.create!(
        contact: contact,
        account: contact.account,
        activity_type: 'automation_email_sent',
        metadata: {
          automation_id: enrollment.email_automation_id,
          step_id: step.id,
          template_id: template.id,
          subject: subject
        }
      )
      
      Result.success(data: { email_sent: true, campaign_id: campaign.id })
    else
      Result.failure("Failed to send email: #{email_result.error}")
    end
  end
  
  def process_wait_step(step, execution)
    wait_duration = parse_wait_duration(step.configuration['wait_duration'])
    
    # Schedule next step execution
    next_execution_time = Time.current + wait_duration
    execution.update!(
      scheduled_at: next_execution_time,
      status: 'waiting'
    )
    
    # Schedule the next step to be processed
    ProcessAutomationExecutionJob.set(wait_until: next_execution_time)
                                .perform_later(execution.id)
    
    Result.success(data: { waiting_until: next_execution_time })
  end
  
  def evaluate_condition(step, contact, enrollment)
    condition_type = step.configuration['condition_type']
    condition_value = step.configuration['condition_value']
    
    result = case condition_type
    when 'tag_has'
      contact.tags.exists?(name: condition_value)
    when 'tag_not_has'
      !contact.tags.exists?(name: condition_value)
    when 'field_equals'
      field_name = step.configuration['field_name']
      contact.send(field_name) == condition_value
    when 'engagement_score'
      operator = step.configuration['operator'] || '>='
      threshold = condition_value.to_f
      evaluate_engagement_condition(contact.engagement_score, operator, threshold)
    when 'email_opened'
      check_email_engagement(contact, enrollment, 'opened')
    when 'email_clicked'
      check_email_engagement(contact, enrollment, 'clicked')
    when 'days_since_signup'
      days_since = (Time.current - contact.created_at) / 1.day
      operator = step.configuration['operator'] || '>='
      threshold = condition_value.to_f
      evaluate_engagement_condition(days_since, operator, threshold)
    else
      false
    end
    
    Result.success(data: { condition_met: result })
  end
  
  def add_tags_to_contact(step, contact)
    tag_names = step.configuration['tags'] || []
    tags_added = []
    
    tag_names.each do |tag_name|
      tag = contact.account.tags.find_or_create_by(name: tag_name.strip)
      unless contact.tags.include?(tag)
        contact.tags << tag
        tags_added << tag_name
      end
    end
    
    # Log activity
    ContactActivityLog.create!(
      contact: contact,
      account: contact.account,
      activity_type: 'tags_added',
      metadata: { tags: tags_added }
    ) if tags_added.any?
    
    Result.success(data: { tags_added: tags_added })
  end
  
  def remove_tags_from_contact(step, contact)
    tag_names = step.configuration['tags'] || []
    tags_removed = []
    
    tag_names.each do |tag_name|
      tag = contact.tags.find_by(name: tag_name.strip)
      if tag
        contact.tags.delete(tag)
        tags_removed << tag_name
      end
    end
    
    # Log activity
    ContactActivityLog.create!(
      contact: contact,
      account: contact.account,
      activity_type: 'tags_removed',
      metadata: { tags: tags_removed }
    ) if tags_removed.any?
    
    Result.success(data: { tags_removed: tags_removed })
  end
  
  def update_contact_field(step, contact)
    field_name = step.configuration['field_name']
    field_value = step.configuration['field_value']
    
    # Validate field exists and is updatable
    unless contact.respond_to?("#{field_name}=")
      return Result.failure("Invalid field: #{field_name}")
    end
    
    old_value = contact.send(field_name)
    contact.update!(field_name => field_value)
    
    # Log activity
    ContactActivityLog.create!(
      contact: contact,
      account: contact.account,
      activity_type: 'field_updated',
      metadata: {
        field_name: field_name,
        old_value: old_value,
        new_value: field_value
      }
    )
    
    Result.success(data: { field_updated: field_name, old_value: old_value, new_value: field_value })
  end
  
  def trigger_webhook(step, contact, enrollment)
    webhook_url = step.configuration['webhook_url']
    webhook_method = step.configuration['method'] || 'POST'
    webhook_headers = step.configuration['headers'] || {}
    
    payload = {
      contact: contact.as_json(except: [:created_at, :updated_at]),
      automation: {
        id: enrollment.email_automation_id,
        name: enrollment.email_automation.name,
        step_id: step.id
      },
      timestamp: Time.current.iso8601
    }
    
    # Add custom fields from step configuration
    custom_data = step.configuration['custom_data'] || {}
    payload.merge!(custom_data)
    
    begin
      response = HTTParty.send(
        webhook_method.downcase.to_sym,
        webhook_url,
        body: payload.to_json,
        headers: webhook_headers.merge('Content-Type' => 'application/json'),
        timeout: 30
      )
      
      if response.success?
        Result.success(data: { webhook_response: response.code })
      else
        Result.failure("Webhook failed with status: #{response.code}")
      end
      
    rescue => error
      Result.failure("Webhook error: #{error.message}")
    end
  end
  
  def handle_successful_execution(execution, result)
    execution.update!(
      status: 'completed',
      completed_at: Time.current,
      execution_data: result.data
    )
    
    # Schedule next step in automation
    schedule_next_step(execution.automation_enrollment, execution.automation_step)
  end
  
  def handle_failed_execution(execution, error_message)
    execution.update!(
      status: 'failed',
      error_message: error_message,
      failed_at: Time.current
    )
    
    # Don't retry if we've exceeded max attempts
    if execution.attempts >= 3
      execution.update!(status: 'failed_permanently')
      
      # Log permanent failure
      Rails.logger.error "Automation execution #{execution.id} failed permanently: #{error_message}"
      
      # Optionally notify account admins of the failure
      NotificationService.notify_automation_failure(execution)
    else
      # Retry with exponential backoff
      retry_delay = [30.seconds, 5.minutes, 30.minutes][execution.attempts - 1] || 1.hour
      ProcessAutomationExecutionJob.set(wait: retry_delay).perform_later(execution.id)
    end
  end
  
  def handle_exception(execution, error)
    execution.update!(
      status: 'failed',
      error_message: error.message,
      failed_at: Time.current
    )
    
    Rails.logger.error "Automation execution #{execution.id} raised exception: #{error.message}"
    Rails.logger.error error.backtrace.join("\n")
    
    # Re-raise to trigger ActiveJob retry logic
    raise error
  end
  
  def schedule_next_step(enrollment, current_step)
    # Find next step in sequence
    next_step = enrollment.email_automation.automation_steps
                          .where('step_order > ?', current_step.step_order)
                          .order(:step_order)
                          .first
    
    return unless next_step
    
    # Check if step has conditions that need to be met
    if current_step.step_type == 'condition'
      last_execution = enrollment.automation_executions
                                .where(automation_step: current_step)
                                .order(:created_at)
                                .last
      
      condition_met = last_execution&.execution_data&.dig('condition_met')
      
      # Handle conditional branching
      if condition_met
        target_step_id = current_step.configuration['success_step_id']
      else
        target_step_id = current_step.configuration['failure_step_id']
      end
      
      if target_step_id
        next_step = enrollment.email_automation.automation_steps.find_by(id: target_step_id)
      end
    end
    
    return unless next_step
    
    # Create next execution
    next_execution = AutomationExecution.create!(
      automation_enrollment: enrollment,
      automation_step: next_step,
      status: 'pending',
      scheduled_at: Time.current
    )
    
    # Schedule immediately unless it's a wait step
    unless next_step.step_type == 'wait'
      ProcessAutomationExecutionJob.perform_later(next_execution.id)
    end
  end
  
  # Helper methods
  
  def personalize_content(content, contact)
    return content unless content&.include?('{{')
    
    # Replace contact fields
    content.gsub(/\{\{(\w+)\}\}/) do |match|
      field_name = $1
      contact.send(field_name) if contact.respond_to?(field_name)
    end
  rescue
    content
  end
  
  def parse_wait_duration(duration_string)
    case duration_string
    when /(\d+)\s*minutes?/
      $1.to_i.minutes
    when /(\d+)\s*hours?/
      $1.to_i.hours
    when /(\d+)\s*days?/
      $1.to_i.days
    when /(\d+)\s*weeks?/
      $1.to_i.weeks
    else
      1.hour # Default wait time
    end
  end
  
  def evaluate_engagement_condition(value, operator, threshold)
    case operator
    when '>'
      value > threshold
    when '>='
      value >= threshold
    when '<'
      value < threshold
    when '<='
      value <= threshold
    when '=='
      value == threshold
    else
      false
    end
  end
  
  def check_email_engagement(contact, enrollment, engagement_type)
    # Check if contact has engaged with recent emails in this automation
    recent_campaigns = Campaign.joins(:contacts)
                              .where(contacts: { id: contact.id })
                              .where(created_at: 30.days.ago..Time.current)
    
    case engagement_type
    when 'opened'
      recent_campaigns.where('open_rate > 0').exists?
    when 'clicked'
      recent_campaigns.where('click_rate > 0').exists?
    else
      false
    end
  end
  
  def create_automation_campaign(template, contact, subject, body, enrollment)
    Campaign.create!(
      account: contact.account,
      user: enrollment.email_automation.account.users.first, # Use first admin user
      template: template,
      name: "Automation: #{enrollment.email_automation.name}",
      subject: subject,
      body: body,
      status: 'sent',
      send_type: 'now',
      recipient_type: 'specific',
      sent_at: Time.current,
      metadata: {
        automation_id: enrollment.email_automation_id,
        contact_id: contact.id,
        is_automation: true
      }
    )
  end
  
  def account_id
    # Extract account ID for rate limiting
    execution = AutomationExecution.find(arguments.first)
    execution.automation_enrollment.email_automation.account_id
  rescue
    nil
  end
end
