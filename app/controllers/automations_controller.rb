# frozen_string_literal: true

class AutomationsController < ApplicationController
  before_action :set_automation, only: [:show, :edit, :update, :destroy, :activate, :pause, :duplicate, :analytics]

  def index
    @automations = current_account.email_automations
                                 .includes(:automation_steps, :automation_enrollments)
                                 .order(:created_at)
    
    @automations = @automations.where(status: params[:status]) if params[:status].present?
    @automations = @automations.where('name ILIKE ?', "%#{params[:search]}%") if params[:search].present?
    
    respond_to do |format|
      format.html
      format.json { render json: automation_list_json }
    end
  end

  def show
    @analytics = automation_analytics_service.automation_analytics(@automation.id).data
    @enrollments = @automation.automation_enrollments.includes(:contact).recent.limit(100)
    
    respond_to do |format|
      format.html
      format.json { render json: automation_detail_json }
    end
  end

  def new
    @automation = current_account.email_automations.build
    @templates = current_account.templates.active
  end

  def create
    @automation = current_account.email_automations.build(automation_params)
    
    if @automation.save
      # Create initial steps if provided
      create_automation_steps if params[:steps].present?
      
      redirect_to @automation, notice: 'Automation was successfully created.'
    else
      @templates = current_account.templates.active
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @templates = current_account.templates.active
  end

  def update
    if @automation.update(automation_params)
      # Update steps if provided
      update_automation_steps if params[:steps].present?
      
      redirect_to @automation, notice: 'Automation was successfully updated.'
    else
      @templates = current_account.templates.active
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @automation.destroy!
    redirect_to automations_url, notice: 'Automation was successfully deleted.'
  end

  def activate
    if @automation.activate!
      render json: { status: 'success', message: 'Automation activated successfully.' }
    else
      render json: { status: 'error', errors: @automation.errors.full_messages }
    end
  end

  def pause
    if @automation.pause!
      render json: { status: 'success', message: 'Automation paused successfully.' }
    else
      render json: { status: 'error', errors: @automation.errors.full_messages }
    end
  end

  def duplicate
    result = automation_service.duplicate_automation(@automation.id, params[:new_name])
    
    if result.success?
      redirect_to result.data, notice: 'Automation duplicated successfully.'
    else
      redirect_to @automation, alert: result.errors.join(', ')
    end
  end

  def analytics
    period = params[:period] || '30_days'
    @analytics = automation_analytics_service.automation_analytics(@automation.id, period).data
    
    respond_to do |format|
      format.html { render partial: 'analytics_data' }
      format.json { render json: @analytics }
    end
  end

  def bulk_action
    automation_ids = params[:automation_ids]
    action = params[:bulk_action]
    
    case action
    when 'activate'
      result = bulk_activate_automations(automation_ids)
    when 'pause'
      result = bulk_pause_automations(automation_ids)
    when 'delete'
      result = bulk_delete_automations(automation_ids)
    else
      result = { success: false, message: 'Invalid action' }
    end
    
    render json: result
  end

  private

  def set_automation
    @automation = current_account.email_automations.find(params[:id])
  end

  def automation_params
    params.require(:email_automation).permit(
      :name, :description, :trigger_type, :status,
      :trigger_conditions, :ab_test_enabled, :ab_test_split_percentage
    )
  end

  def automation_service
    @automation_service ||= EmailAutomationService.new(account: current_account)
  end

  def automation_analytics_service
    @automation_analytics_service ||= EmailAutomationService.new(account: current_account)
  end

  def create_automation_steps
    params[:steps].each_with_index do |step_params, index|
      @automation.automation_steps.create!(
        step_type: step_params[:step_type],
        step_order: index + 1,
        delay_amount: step_params[:delay_amount] || 0,
        delay_unit: step_params[:delay_unit] || 'hours',
        email_template_id: step_params[:email_template_id],
        custom_subject: step_params[:custom_subject],
        custom_body: step_params[:custom_body],
        conditions: step_params[:conditions] || {}
      )
    end
  end

  def update_automation_steps
    # Remove existing steps and recreate
    @automation.automation_steps.destroy_all
    create_automation_steps
  end

  def bulk_activate_automations(automation_ids)
    automations = current_account.email_automations.where(id: automation_ids)
    activated_count = 0
    
    automations.each do |automation|
      if automation.activate!
        activated_count += 1
      end
    end
    
    {
      success: true,
      message: "#{activated_count} automations activated successfully.",
      activated_count: activated_count
    }
  rescue => e
    { success: false, message: "Error activating automations: #{e.message}" }
  end

  def bulk_pause_automations(automation_ids)
    automations = current_account.email_automations.where(id: automation_ids)
    paused_count = 0
    
    automations.each do |automation|
      if automation.pause!
        paused_count += 1
      end
    end
    
    {
      success: true,
      message: "#{paused_count} automations paused successfully.",
      paused_count: paused_count
    }
  rescue => e
    { success: false, message: "Error pausing automations: #{e.message}" }
  end

  def bulk_delete_automations(automation_ids)
    automations = current_account.email_automations.where(id: automation_ids)
    deleted_count = automations.count
    
    # Schedule background job for safe deletion
    BulkOperationJob.perform_later(
      operation: 'bulk_delete_automations',
      resource_ids: automation_ids,
      account_id: current_account.id,
      user_id: current_user.id
    )
    
    {
      success: true,
      message: "#{deleted_count} automations queued for deletion.",
      deleted_count: deleted_count
    }
  rescue => e
    { success: false, message: "Error deleting automations: #{e.message}" }
  end

  def automation_list_json
    @automations.map do |automation|
      {
        id: automation.id,
        name: automation.name,
        description: automation.description,
        status: automation.status,
        trigger_type: automation.trigger_type,
        total_enrollments: automation.total_enrollments,
        active_enrollments: automation.active_enrollments,
        completion_rate: automation.completion_rate,
        created_at: automation.created_at,
        updated_at: automation.updated_at
      }
    end
  end

  def automation_detail_json
    {
      automation: {
        id: @automation.id,
        name: @automation.name,
        description: @automation.description,
        status: @automation.status,
        trigger_type: @automation.trigger_type,
        trigger_conditions: @automation.trigger_conditions,
        steps: @automation.automation_steps.order(:step_order).map do |step|
          {
            id: step.id,
            step_type: step.step_type,
            step_order: step.step_order,
            delay_amount: step.delay_amount,
            delay_unit: step.delay_unit,
            email_template_id: step.email_template_id,
            custom_subject: step.custom_subject,
            conditions: step.conditions
          }
        end
      },
      analytics: @analytics,
      recent_enrollments: @enrollments.map do |enrollment|
        {
          id: enrollment.id,
          contact_email: enrollment.contact.email,
          status: enrollment.status,
          current_step: enrollment.current_step,
          enrolled_at: enrollment.enrolled_at,
          progress_percentage: enrollment.progress_percentage
        }
      end
    }
  end
end
