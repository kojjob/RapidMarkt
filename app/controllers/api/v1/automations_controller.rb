# frozen_string_literal: true

class Api::V1::AutomationsController < Api::BaseController
  before_action :set_automation, only: [ :show, :update, :destroy, :activate, :pause, :duplicate, :analytics, :enrollments ]

  # GET /api/v1/automations
  def index
    @automations = current_account.email_automations
                                 .includes(:automation_steps, :automation_enrollments)
                                 .order(:created_at)

    @automations = filter_automations(@automations)
    @automations = @automations.page(params[:page]).per(params[:per_page] || 25)

    render_success(
      automations: serialize_automations(@automations),
      pagination: pagination_data(@automations)
    )
  end

  # GET /api/v1/automations/:id
  def show
    analytics = automation_service.automation_analytics(@automation.id, params[:period] || "30_days")

    render_success(
      automation: serialize_automation_detail(@automation),
      analytics: analytics.success? ? analytics.data : {}
    )
  end

  # POST /api/v1/automations
  def create
    @automation = current_account.email_automations.build(automation_params)

    if @automation.save
      create_automation_steps if automation_steps_params.present?

      render_success(
        automation: serialize_automation_detail(@automation),
        message: "Automation created successfully"
      )
    else
      render_validation_errors(@automation)
    end
  end

  # PATCH /api/v1/automations/:id
  def update
    if @automation.update(automation_params)
      update_automation_steps if automation_steps_params.present?

      render_success(
        automation: serialize_automation_detail(@automation),
        message: "Automation updated successfully"
      )
    else
      render_validation_errors(@automation)
    end
  end

  # DELETE /api/v1/automations/:id
  def destroy
    @automation.destroy!
    render_success(message: "Automation deleted successfully")
  end

  # POST /api/v1/automations/:id/activate
  def activate
    if @automation.activate!
      render_success(
        automation: serialize_automation_detail(@automation),
        message: "Automation activated successfully"
      )
    else
      render_validation_errors(@automation)
    end
  end

  # POST /api/v1/automations/:id/pause
  def pause
    if @automation.pause!
      render_success(
        automation: serialize_automation_detail(@automation),
        message: "Automation paused successfully"
      )
    else
      render_validation_errors(@automation)
    end
  end

  # POST /api/v1/automations/:id/duplicate
  def duplicate
    result = automation_service.duplicate_automation(@automation.id, params[:new_name])

    if result.success?
      render_success(
        automation: serialize_automation_detail(result.data),
        message: "Automation duplicated successfully"
      )
    else
      render_error("Failed to duplicate automation", result.errors)
    end
  end

  # GET /api/v1/automations/:id/analytics
  def analytics
    period = params[:period] || "30_days"
    result = automation_service.automation_analytics(@automation.id, period)

    if result.success?
      render_success(analytics: result.data)
    else
      render_error("Failed to fetch analytics", result.errors)
    end
  end

  # GET /api/v1/automations/:id/enrollments
  def enrollments
    @enrollments = @automation.automation_enrollments
                             .includes(:contact, :automation_executions)
                             .order(created_at: :desc)

    @enrollments = filter_enrollments(@enrollments)
    @enrollments = @enrollments.page(params[:page]).per(params[:per_page] || 25)

    render_success(
      enrollments: serialize_enrollments(@enrollments),
      pagination: pagination_data(@enrollments)
    )
  end

  # POST /api/v1/automations/bulk_action
  def bulk_action
    automation_ids = params[:automation_ids]
    action = params[:action]

    unless automation_ids.present? && action.present?
      return render_error("Missing required parameters: automation_ids and action")
    end

    result = execute_bulk_action(automation_ids, action)

    if result[:success]
      render_success(
        data: result.except(:success),
        message: result[:message]
      )
    else
      render_error(result[:message])
    end
  end

  private

  def set_automation
    @automation = current_account.email_automations.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Automation not found", [], :not_found)
  end

  def automation_service
    @automation_service ||= EmailAutomationService.new(account: current_account)
  end

  def automation_params
    params.require(:automation).permit(
      :name, :description, :trigger_type, :status,
      trigger_conditions: {}
    )
  end

  def automation_steps_params
    params[:steps] || []
  end

  def filter_automations(automations)
    automations = automations.where(status: params[:status]) if params[:status].present?
    automations = automations.where("name ILIKE ?", "%#{params[:search]}%") if params[:search].present?
    automations = automations.where(trigger_type: params[:trigger_type]) if params[:trigger_type].present?
    automations
  end

  def filter_enrollments(enrollments)
    enrollments = enrollments.where(status: params[:status]) if params[:status].present?
    enrollments = enrollments.joins(:contact).where("contacts.email ILIKE ?", "%#{params[:contact_email]}%") if params[:contact_email].present?
    enrollments
  end

  def create_automation_steps
    automation_steps_params.each_with_index do |step_params, index|
      @automation.automation_steps.create!(
        step_type: step_params[:step_type],
        step_order: index + 1,
        delay_amount: step_params[:delay_amount] || 0,
        delay_unit: step_params[:delay_unit] || "hours",
        email_template_id: step_params[:email_template_id],
        custom_subject: step_params[:custom_subject],
        custom_body: step_params[:custom_body],
        conditions: step_params[:conditions] || {}
      )
    end
  end

  def update_automation_steps
    @automation.automation_steps.destroy_all
    create_automation_steps
  end

  def execute_bulk_action(automation_ids, action)
    automations = current_account.email_automations.where(id: automation_ids)

    case action
    when "activate"
      bulk_activate_automations(automations)
    when "pause"
      bulk_pause_automations(automations)
    when "delete"
      bulk_delete_automations(automations)
    else
      { success: false, message: "Invalid action" }
    end
  end

  def bulk_activate_automations(automations)
    activated_count = 0
    failed_count = 0

    automations.each do |automation|
      if automation.activate!
        activated_count += 1
      else
        failed_count += 1
      end
    end

    {
      success: true,
      message: "#{activated_count} automations activated successfully.",
      activated_count: activated_count,
      failed_count: failed_count
    }
  rescue => e
    { success: false, message: "Error activating automations: #{e.message}" }
  end

  def bulk_pause_automations(automations)
    paused_count = 0
    failed_count = 0

    automations.each do |automation|
      if automation.pause!
        paused_count += 1
      else
        failed_count += 1
      end
    end

    {
      success: true,
      message: "#{paused_count} automations paused successfully.",
      paused_count: paused_count,
      failed_count: failed_count
    }
  rescue => e
    { success: false, message: "Error pausing automations: #{e.message}" }
  end

  def bulk_delete_automations(automations)
    deleted_count = automations.count

    # Schedule background job for safe deletion
    BulkOperationJob.perform_later(
      operation: "bulk_delete_automations",
      resource_ids: automations.pluck(:id),
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

  def serialize_automations(automations)
    automations.map { |automation| serialize_automation(automation) }
  end

  def serialize_automation(automation)
    {
      id: automation.id,
      name: automation.name,
      description: automation.description,
      status: automation.status,
      trigger_type: automation.trigger_type,
      trigger_conditions: automation.trigger_conditions,
      total_enrollments: automation.total_enrollments,
      active_enrollments: automation.active_enrollments,
      completion_rate: automation.completion_rate,
      created_at: automation.created_at,
      updated_at: automation.updated_at
    }
  end

  def serialize_automation_detail(automation)
    serialize_automation(automation).merge(
      steps: automation.automation_steps.order(:step_order).map do |step|
        {
          id: step.id,
          step_type: step.step_type,
          step_order: step.step_order,
          delay_amount: step.delay_amount,
          delay_unit: step.delay_unit,
          email_template_id: step.email_template_id,
          custom_subject: step.custom_subject,
          custom_body: step.custom_body,
          conditions: step.conditions
        }
      end
    )
  end

  def serialize_enrollments(enrollments)
    enrollments.map do |enrollment|
      {
        id: enrollment.id,
        contact: {
          id: enrollment.contact.id,
          email: enrollment.contact.email,
          first_name: enrollment.contact.first_name,
          last_name: enrollment.contact.last_name
        },
        status: enrollment.status,
        current_step: enrollment.current_step,
        progress_percentage: enrollment.progress_percentage,
        enrolled_at: enrollment.enrolled_at,
        completed_at: enrollment.completed_at,
        duration: enrollment.duration
      }
    end
  end

  def pagination_data(collection)
    {
      current_page: collection.current_page,
      total_pages: collection.total_pages,
      total_count: collection.total_count,
      per_page: collection.limit_value
    }
  end
end
