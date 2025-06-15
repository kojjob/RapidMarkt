# frozen_string_literal: true

# Scheduled job to process automation executions that are due
# Runs every minute to check for pending automations
class ProcessScheduledAutomationsJob < ApplicationJob
  queue_as QueuePriorities::AUTOMATION_SCHEDULER
  
  # Don't retry this job - it runs every minute anyway
  retry_on StandardError, attempts: 1
  
  def perform
    Rails.logger.info "Processing scheduled automations at #{Time.current}"
    
    # Process due automation executions
    process_due_executions
    
    # Process new enrollments
    process_new_enrollments
    
    # Clean up old executions
    cleanup_old_executions
    
    Rails.logger.info "Finished processing scheduled automations"
  end
  
  private
  
  def process_due_executions
    # Find executions that are due to be processed
    due_executions = AutomationExecution.includes(:automation_step, :automation_enrollment)
                                       .where(status: ['pending', 'waiting'])
                                       .where('scheduled_at <= ?', Time.current)
                                       .limit(500) # Process in batches to avoid overwhelming the system
    
    Rails.logger.info "Found #{due_executions.count} due executions to process"
    
    due_executions.find_each do |execution|
      # Skip if enrollment is no longer active
      next unless execution.automation_enrollment.active?
      
      # Skip if contact is unsubscribed or deleted
      contact = execution.automation_enrollment.contact
      next unless contact&.status == 'subscribed'
      
      # Enqueue the execution job
      ProcessAutomationExecutionJob.perform_later(execution.id)
    end
  end
  
  def process_new_enrollments
    # Find active automations that might have new enrollments
    active_automations = EmailAutomation.active.includes(:automation_steps)
    
    active_automations.find_each do |automation|
      process_automation_enrollments(automation)
    end
  end
  
  def process_automation_enrollments(automation)
    # Check for new contacts that should be enrolled based on triggers
    case automation.trigger_type
    when 'immediate'
      # Contacts are enrolled immediately when created/updated
      # This is handled in the ContactManagementService
      return
      
    when 'tag_added'
      process_tag_trigger_enrollments(automation)
      
    when 'date_based'
      process_date_based_enrollments(automation)
      
    when 'behavior_based'
      process_behavior_based_enrollments(automation)
      
    when 'manual'
      # Manual enrollments are handled through the UI
      return
    end
  end
  
  def process_tag_trigger_enrollments(automation)
    trigger_tag = automation.trigger_conditions['tag_name']
    return unless trigger_tag
    
    # Find contacts with the trigger tag who aren't enrolled
    contacts_with_tag = automation.account.contacts
                                 .joins(:tags)
                                 .where(tags: { name: trigger_tag })
                                 .where(status: 'subscribed')
                                 .where.not(
                                   id: automation.automation_enrollments
                                                .select(:contact_id)
                                 )
    
    contacts_with_tag.find_each do |contact|
      enroll_contact_in_automation(contact, automation)
    end
  end
  
  def process_date_based_enrollments(automation)
    date_field = automation.trigger_conditions['date_field']
    days_after = automation.trigger_conditions['days_after'].to_i
    
    return unless date_field && days_after
    
    # Calculate the target date
    target_date = Date.current - days_after.days
    
    # Find contacts who match the date criteria
    contacts = automation.account.contacts
                        .where(status: 'subscribed')
                        .where(date_field => target_date.beginning_of_day..target_date.end_of_day)
                        .where.not(
                          id: automation.automation_enrollments
                                       .select(:contact_id)
                        )
    
    contacts.find_each do |contact|
      enroll_contact_in_automation(contact, automation)
    end
  end
  
  def process_behavior_based_enrollments(automation)
    behavior_type = automation.trigger_conditions['behavior_type']
    
    case behavior_type
    when 'no_email_open'
      process_no_engagement_enrollments(automation, 'email_opened')
    when 'no_email_click'
      process_no_engagement_enrollments(automation, 'email_clicked')
    when 'cart_abandonment'
      process_cart_abandonment_enrollments(automation)
    when 'website_visit'
      process_website_visit_enrollments(automation)
    end
  end
  
  def process_no_engagement_enrollments(automation, engagement_type)
    days_without_engagement = automation.trigger_conditions['days_without_engagement'].to_i
    return unless days_without_engagement > 0
    
    cutoff_date = Date.current - days_without_engagement.days
    
    # Find contacts who haven't engaged recently
    contacts = automation.account.contacts
                        .where(status: 'subscribed')
                        .where('last_email_opened_at < ? OR last_email_opened_at IS NULL', cutoff_date)
                        .where.not(
                          id: automation.automation_enrollments
                                       .select(:contact_id)
                        )
    
    contacts.find_each do |contact|
      enroll_contact_in_automation(contact, automation)
    end
  end
  
  def process_cart_abandonment_enrollments(automation)
    # This would integrate with e-commerce data
    # For now, we'll check for contacts with 'cart_abandoned' tag
    abandoned_contacts = automation.account.contacts
                                  .joins(:tags)
                                  .where(tags: { name: 'cart_abandoned' })
                                  .where(status: 'subscribed')
                                  .where('updated_at >= ?', 24.hours.ago)
                                  .where.not(
                                    id: automation.automation_enrollments
                                                 .select(:contact_id)
                                  )
    
    abandoned_contacts.find_each do |contact|
      enroll_contact_in_automation(contact, automation)
    end
  end
  
  def process_website_visit_enrollments(automation)
    # This would integrate with website tracking
    # For now, we'll check for contacts with recent activity
    recent_visitors = automation.account.contacts
                               .where(status: 'subscribed')
                               .where('last_activity_at >= ?', 1.hour.ago)
                               .where.not(
                                 id: automation.automation_enrollments
                                          .select(:contact_id)
                               )
    
    recent_visitors.find_each do |contact|
      enroll_contact_in_automation(contact, automation)
    end
  end
  
  def enroll_contact_in_automation(contact, automation)
    # Create enrollment
    enrollment = AutomationEnrollment.create!(
      email_automation: automation,
      contact: contact,
      status: 'active',
      enrolled_at: Time.current
    )
    
    # Create execution for first step
    first_step = automation.automation_steps.order(:step_order).first
    return unless first_step
    
    execution = AutomationExecution.create!(
      automation_enrollment: enrollment,
      automation_step: first_step,
      status: 'pending',
      scheduled_at: Time.current
    )
    
    # Enqueue the first execution
    ProcessAutomationExecutionJob.perform_later(execution.id)
    
    Rails.logger.info "Enrolled contact #{contact.id} in automation #{automation.id}"
  end
  
  def cleanup_old_executions
    # Clean up completed executions older than 90 days
    old_executions = AutomationExecution.where(status: 'completed')
                                       .where('completed_at < ?', 90.days.ago)
    
    deleted_count = old_executions.delete_all
    
    Rails.logger.info "Cleaned up #{deleted_count} old automation executions" if deleted_count > 0
    
    # Clean up failed executions older than 30 days
    old_failed_executions = AutomationExecution.where(status: ['failed', 'failed_permanently'])
                                              .where('failed_at < ?', 30.days.ago)
    
    failed_deleted_count = old_failed_executions.delete_all
    
    Rails.logger.info "Cleaned up #{failed_deleted_count} old failed executions" if failed_deleted_count > 0
  end
end
