# frozen_string_literal: true

class EmailAutomationService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attr_reader :account, :errors

  def initialize(account:)
    @account = account
    @errors = ActiveModel::Errors.new(self)
  end

  # Create a drip campaign sequence
  def create_drip_sequence(params)
    sequence_name = params[:name]
    trigger_conditions = params[:trigger_conditions] || {}
    emails = params[:emails] || []
    
    return Result.failure("Sequence name is required") if sequence_name.blank?
    return Result.failure("At least one email is required") if emails.empty?

    ApplicationRecord.transaction do
      # Create the automation sequence
      automation = @account.email_automations.create!(
        name: sequence_name,
        description: params[:description],
        trigger_type: params[:trigger_type] || 'manual',
        trigger_conditions: trigger_conditions,
        status: 'draft'
      )

      # Create email steps
      emails.each_with_index do |email_data, index|
        automation.automation_steps.create!(
          step_type: 'email',
          step_order: index + 1,
          delay_amount: email_data[:delay_amount] || 0,
          delay_unit: email_data[:delay_unit] || 'days',
          email_template_id: email_data[:template_id],
          custom_subject: email_data[:custom_subject],
          custom_body: email_data[:custom_body],
          conditions: email_data[:conditions] || {}
        )
      end

      audit_log("Drip sequence '#{sequence_name}' created with #{emails.count} emails")
      Result.success(automation)
    end
  rescue => e
    Rails.logger.error "Drip sequence creation failed: #{e.message}"
    Result.failure("Failed to create drip sequence: #{e.message}")
  end

  # Set up welcome email automation
  def setup_welcome_automation(template_id, delay_hours = 0)
    welcome_automation = @account.email_automations.find_or_create_by(
      trigger_type: 'contact_subscribed',
      name: 'Welcome Email'
    ) do |automation|
      automation.description = 'Automatic welcome email for new subscribers'
      automation.status = 'active'
    end

    # Clear existing steps and create new one
    welcome_automation.automation_steps.destroy_all
    
    welcome_automation.automation_steps.create!(
      step_type: 'email',
      step_order: 1,
      delay_amount: delay_hours,
      delay_unit: 'hours',
      email_template_id: template_id
    )

    audit_log("Welcome automation configured")
    Result.success(welcome_automation)
  end

  # Set up abandoned cart recovery (for e-commerce integrations)
  def setup_cart_recovery_automation(templates_and_delays)
    recovery_automation = @account.email_automations.find_or_create_by(
      trigger_type: 'cart_abandoned',
      name: 'Cart Recovery'
    ) do |automation|
      automation.description = 'Recover abandoned shopping carts'
      automation.status = 'active'
      automation.trigger_conditions = { 
        cart_value_min: 10.0,
        abandoned_hours: 1 
      }
    end

    # Clear existing steps
    recovery_automation.automation_steps.destroy_all

    # Create recovery sequence
    templates_and_delays.each_with_index do |(template_id, delay_hours), index|
      recovery_automation.automation_steps.create!(
        step_type: 'email',
        step_order: index + 1,
        delay_amount: delay_hours,
        delay_unit: 'hours',
        email_template_id: template_id,
        conditions: {
          'cart_still_abandoned' => true,
          'customer_not_purchased' => true
        }
      )
    end

    audit_log("Cart recovery automation configured with #{templates_and_delays.count} steps")
    Result.success(recovery_automation)
  end

  # Set up re-engagement automation for inactive contacts
  def setup_reengagement_automation(inactive_days = 90)
    reengagement_automation = @account.email_automations.find_or_create_by(
      trigger_type: 'contact_inactive',
      name: 'Re-engagement Campaign'
    ) do |automation|
      automation.description = "Re-engage contacts inactive for #{inactive_days}+ days"
      automation.status = 'active'
      automation.trigger_conditions = { 
        inactive_days: inactive_days,
        last_engagement: 'email_open'
      }
    end

    # Create re-engagement sequence
    reengagement_steps = [
      { delay: 0, subject: "We miss you! Here's what you've been missing", template_type: 'reengagement_soft' },
      { delay: 7, subject: "One last try - special offer inside", template_type: 'reengagement_offer' },
      { delay: 14, subject: "Confirm you want to stay subscribed", template_type: 'reengagement_confirmation' }
    ]

    reengagement_automation.automation_steps.destroy_all

    reengagement_steps.each_with_index do |step_data, index|
      # Find or create appropriate template
      template = find_or_create_reengagement_template(step_data[:template_type], step_data[:subject])
      
      reengagement_automation.automation_steps.create!(
        step_type: 'email',
        step_order: index + 1,
        delay_amount: step_data[:delay],
        delay_unit: 'days',
        email_template_id: template.id,
        custom_subject: step_data[:subject]
      )
    end

    audit_log("Re-engagement automation configured for #{inactive_days} day inactive contacts")
    Result.success(reengagement_automation)
  end

  # Process automation triggers
  def process_triggers(trigger_type, context = {})
    automations = @account.email_automations.active.where(trigger_type: trigger_type)
    processed_count = 0

    automations.each do |automation|
      if trigger_conditions_met?(automation, context)
        result = execute_automation(automation, context)
        processed_count += 1 if result.success?
      end
    end

    Result.success("Processed #{processed_count} automations for trigger #{trigger_type}")
  end

  # Execute a specific automation for a contact
  def execute_automation(automation, context)
    contact = context[:contact]
    return Result.failure("Contact is required") unless contact

    # Check if contact is already in this automation
    existing_enrollment = automation.automation_enrollments.find_by(contact: contact)
    
    if existing_enrollment&.active?
      return Result.success("Contact already enrolled in automation")
    end

    # Create new enrollment
    enrollment = automation.automation_enrollments.create!(
      contact: contact,
      status: 'active',
      enrolled_at: Time.current,
      current_step: 1,
      context: context.except(:contact)
    )

    # Schedule first step
    first_step = automation.automation_steps.order(:step_order).first
    if first_step
      schedule_automation_step(enrollment, first_step)
    end

    audit_log("Contact #{contact.email} enrolled in automation '#{automation.name}'")
    Result.success(enrollment)
  rescue => e
    Rails.logger.error "Automation execution failed: #{e.message}"
    Result.failure("Failed to execute automation: #{e.message}")
  end

  # Process scheduled automation steps
  def process_scheduled_steps
    due_executions = AutomationExecution.due_for_execution
    processed_count = 0

    due_executions.find_each do |execution|
      begin
        result = execute_automation_step(execution)
        processed_count += 1 if result.success?
      rescue => e
        Rails.logger.error "Failed to execute automation step #{execution.id}: #{e.message}"
        execution.update!(status: 'failed', error_message: e.message)
      end
    end

    Result.success("Processed #{processed_count} scheduled automation steps")
  end

  # A/B test automation sequences
  def setup_automation_ab_test(automation_id, variant_params)
    original_automation = @account.email_automations.find(automation_id)
    
    # Create variant automation
    variant_automation = original_automation.dup
    variant_automation.name = "#{original_automation.name} (Variant B)"
    variant_automation.assign_attributes(variant_params.except(:steps))
    variant_automation.ab_test_original_id = original_automation.id
    variant_automation.ab_test_split_percentage = variant_params[:split_percentage] || 50
    
    ApplicationRecord.transaction do
      variant_automation.save!
      
      # Copy and modify steps if provided
      if variant_params[:steps].present?
        create_variant_steps(variant_automation, variant_params[:steps])
      else
        copy_automation_steps(original_automation, variant_automation)
      end
      
      # Mark original as A/B test
      original_automation.update!(
        ab_test_enabled: true,
        ab_test_split_percentage: 100 - variant_automation.ab_test_split_percentage
      )
      
      audit_log("A/B test created for automation '#{original_automation.name}'")
      Result.success(variant_automation)
    end
  rescue => e
    Rails.logger.error "A/B test setup failed: #{e.message}"
    Result.failure("Failed to setup A/B test: #{e.message}")
  end

  # Get automation performance analytics
  def automation_analytics(automation_id, period = '30_days')
    automation = @account.email_automations.find(automation_id)
    
    start_date = case period
                 when '7_days' then 7.days.ago
                 when '30_days' then 30.days.ago
                 when '90_days' then 90.days.ago
                 else 30.days.ago
                 end

    enrollments = automation.automation_enrollments.where('enrolled_at >= ?', start_date)
    
    analytics = {
      total_enrollments: enrollments.count,
      active_enrollments: enrollments.active.count,
      completed_enrollments: enrollments.completed.count,
      conversion_rate: calculate_automation_conversion_rate(enrollments),
      step_performance: analyze_step_performance(automation, enrollments),
      revenue_attribution: calculate_revenue_attribution(enrollments),
      drop_off_analysis: analyze_drop_off_points(automation, enrollments)
    }

    Result.success(analytics)
  end

  private

  def trigger_conditions_met?(automation, context)
    return true if automation.trigger_conditions.blank?

    conditions = automation.trigger_conditions
    
    case automation.trigger_type
    when 'contact_subscribed'
      true # Always trigger for new subscriptions
    when 'contact_inactive'
      contact = context[:contact]
      return false unless contact
      
      inactive_days = conditions['inactive_days'] || 90
      last_activity = contact.last_opened_at || contact.created_at
      (Date.current - last_activity.to_date).to_i >= inactive_days
    when 'cart_abandoned'
      cart_value = context[:cart_value] || 0
      min_value = conditions['cart_value_min'] || 0
      
      cart_value >= min_value
    else
      true
    end
  end

  def schedule_automation_step(enrollment, step)
    execution_time = case step.delay_unit
                     when 'minutes'
                       step.delay_amount.minutes.from_now
                     when 'hours'
                       step.delay_amount.hours.from_now
                     when 'days'
                       step.delay_amount.days.from_now
                     when 'weeks'
                       step.delay_amount.weeks.from_now
                     else
                       Time.current
                     end

    AutomationExecution.create!(
      automation_enrollment: enrollment,
      automation_step: step,
      scheduled_at: execution_time,
      status: 'scheduled'
    )
  end

  def execute_automation_step(execution)
    step = execution.automation_step
    enrollment = execution.automation_enrollment
    contact = enrollment.contact

    case step.step_type
    when 'email'
      send_automation_email(step, contact, enrollment.context)
    when 'wait'
      # Just mark as completed, next step will be scheduled
      execution.update!(status: 'completed', executed_at: Time.current)
    when 'condition'
      # Evaluate condition and branch accordingly
      evaluate_automation_condition(step, contact, enrollment)
    else
      execution.update!(status: 'skipped', executed_at: Time.current)
    end

    # Schedule next step if not the last one
    next_step = step.automation.automation_steps.where('step_order > ?', step.step_order).order(:step_order).first
    if next_step
      schedule_automation_step(enrollment, next_step)
      enrollment.update!(current_step: next_step.step_order)
    else
      enrollment.update!(status: 'completed', completed_at: Time.current)
    end

    execution.update!(status: 'completed', executed_at: Time.current)
    Result.success(execution)
  end

  def send_automation_email(step, contact, context)
    template = Template.find(step.email_template_id)
    
    # Create campaign for this automation email
    campaign = @account.campaigns.create!(
      name: "#{step.automation.name} - Step #{step.step_order}",
      subject: step.custom_subject || template.subject,
      template: template,
      status: 'sending',
      user: Current.user || @account.users.first,
      automation_step_id: step.id
    )

    # Add contact to campaign
    campaign.campaign_contacts.create!(
      contact: contact,
      status: 'sending'
    )

    # Send the email
    CampaignSenderJob.perform_later(campaign.id)
  end

  def evaluate_automation_condition(step, contact, enrollment)
    # This would evaluate conditions and potentially branch the automation
    # For now, just continue to next step
    true
  end

  def find_or_create_reengagement_template(template_type, subject)
    template = @account.templates.find_by(template_type: template_type)
    
    unless template
      template = @account.templates.create!(
        name: "#{template_type.humanize} Template",
        subject: subject,
        body: generate_reengagement_template_body(template_type),
        template_type: 'email',
        status: 'active'
      )
    end
    
    template
  end

  def generate_reengagement_template_body(template_type)
    case template_type
    when 'reengagement_soft'
      <<~HTML
        <h2>We miss you, {{contact.first_name}}!</h2>
        <p>It's been a while since we've heard from you. Here's what you've been missing:</p>
        <ul>
          <li>New features and updates</li>
          <li>Exclusive content</li>
          <li>Special offers</li>
        </ul>
        <a href="#" style="background: #007bff; color: white; padding: 10px 20px; text-decoration: none;">
          Catch up now
        </a>
      HTML
    when 'reengagement_offer'
      <<~HTML
        <h2>One last try, {{contact.first_name}}</h2>
        <p>We really want to keep you in the loop! Here's a special 20% off offer just for you:</p>
        <div style="text-align: center; margin: 20px 0;">
          <span style="font-size: 24px; font-weight: bold; color: #28a745;">SAVE20</span>
        </div>
        <a href="#" style="background: #28a745; color: white; padding: 10px 20px; text-decoration: none;">
          Claim your discount
        </a>
      HTML
    when 'reengagement_confirmation'
      <<~HTML
        <h2>Do you still want to hear from us?</h2>
        <p>Hi {{contact.first_name}}, we notice you haven't been opening our emails lately.</p>
        <p>If you'd like to keep receiving updates from us, please click the button below:</p>
        <a href="#" style="background: #007bff; color: white; padding: 10px 20px; text-decoration: none;">
          Yes, keep me subscribed
        </a>
        <p><small>If we don't hear from you, we'll respect your inbox and stop sending emails.</small></p>
      HTML
    else
      "<p>Default reengagement template</p>"
    end
  end

  def create_variant_steps(variant_automation, variant_steps)
    variant_steps.each_with_index do |step_data, index|
      variant_automation.automation_steps.create!(
        step_type: step_data[:step_type] || 'email',
        step_order: index + 1,
        delay_amount: step_data[:delay_amount] || 0,
        delay_unit: step_data[:delay_unit] || 'days',
        email_template_id: step_data[:template_id],
        custom_subject: step_data[:custom_subject],
        custom_body: step_data[:custom_body],
        conditions: step_data[:conditions] || {}
      )
    end
  end

  def copy_automation_steps(original_automation, variant_automation)
    original_automation.automation_steps.order(:step_order).each do |original_step|
      variant_automation.automation_steps.create!(
        step_type: original_step.step_type,
        step_order: original_step.step_order,
        delay_amount: original_step.delay_amount,
        delay_unit: original_step.delay_unit,
        email_template_id: original_step.email_template_id,
        custom_subject: original_step.custom_subject,
        custom_body: original_step.custom_body,
        conditions: original_step.conditions
      )
    end
  end

  def calculate_automation_conversion_rate(enrollments)
    return 0 if enrollments.empty?
    
    completed = enrollments.completed.count
    (completed.to_f / enrollments.count * 100).round(2)
  end

  def analyze_step_performance(automation, enrollments)
    step_performance = {}
    
    automation.automation_steps.order(:step_order).each do |step|
      executions = AutomationExecution.joins(:automation_enrollment)
                                     .where(automation_step: step, automation_enrollments: { id: enrollments.ids })
      
      step_performance[step.id] = {
        step_order: step.step_order,
        step_type: step.step_type,
        total_executions: executions.count,
        completed_executions: executions.completed.count,
        failed_executions: executions.failed.count,
        completion_rate: executions.any? ? (executions.completed.count.to_f / executions.count * 100).round(2) : 0
      }
    end
    
    step_performance
  end

  def calculate_revenue_attribution(enrollments)
    # This would calculate revenue attributed to the automation
    # Placeholder for now
    {
      total_revenue: 0,
      average_revenue_per_enrollment: 0,
      conversion_value: 0
    }
  end

  def analyze_drop_off_points(automation, enrollments)
    drop_offs = {}
    
    automation.automation_steps.order(:step_order).each do |step|
      enrolled_at_step = enrollments.where('current_step >= ?', step.step_order).count
      next_step = automation.automation_steps.where('step_order > ?', step.step_order).order(:step_order).first
      
      if next_step
        continued_to_next = enrollments.where('current_step >= ?', next_step.step_order).count
        drop_off_rate = enrolled_at_step > 0 ? ((enrolled_at_step - continued_to_next).to_f / enrolled_at_step * 100).round(2) : 0
        
        drop_offs[step.id] = {
          step_order: step.step_order,
          enrolled_count: enrolled_at_step,
          continued_count: continued_to_next,
          drop_off_rate: drop_off_rate
        }
      end
    end
    
    drop_offs
  end

  def audit_log(message)
    @account.audit_logs.create!(
      user: Current.user,
      action: 'email_automation',
      details: message,
      resource_type: 'EmailAutomation'
    )
  rescue => e
    Rails.logger.warn "Failed to create audit log: #{e.message}"
  end

  # Result class for consistent return values
  class Result
    attr_reader :data, :errors, :success

    def initialize(success:, data: nil, errors: nil)
      @success = success
      @data = data
      @errors = errors
    end

    def self.success(data = nil)
      new(success: true, data: data)
    end

    def self.failure(errors)
      new(success: false, errors: errors)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
