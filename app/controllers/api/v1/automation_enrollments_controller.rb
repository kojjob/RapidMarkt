# frozen_string_literal: true

class Api::V1::AutomationEnrollmentsController < Api::BaseController
  before_action :set_enrollment, only: [ :show, :destroy, :pause, :resume ]

  # GET /api/v1/automation_enrollments
  def index
    @enrollments = current_account.email_automations
                                 .joins(:automation_enrollments)
                                 .includes(automation_enrollments: [ :contact, :automation_executions ])
                                 .flat_map(&:automation_enrollments)

    @enrollments = filter_enrollments(@enrollments)
    @enrollments = Kaminari.paginate_array(@enrollments)
                          .page(params[:page])
                          .per(params[:per_page] || 25)

    render_success(
      enrollments: serialize_enrollments(@enrollments),
      pagination: pagination_data(@enrollments)
    )
  end

  # GET /api/v1/automation_enrollments/:id
  def show
    render_success(
      enrollment: serialize_enrollment_detail(@enrollment)
    )
  end

  # POST /api/v1/automation_enrollments
  def create
    automation = current_account.email_automations.find(enrollment_params[:automation_id])
    contact = current_account.contacts.find(enrollment_params[:contact_id])

    result = automation_service.execute_automation(automation, {
      contact: contact,
      context: enrollment_params[:context] || {}
    })

    if result.success?
      render_success(
        enrollment: serialize_enrollment_detail(result.data),
        message: "Contact enrolled in automation successfully"
      )
    else
      render_error("Failed to enroll contact", result.errors)
    end
  end

  # DELETE /api/v1/automation_enrollments/:id
  def destroy
    @enrollment.destroy!
    render_success(message: "Enrollment deleted successfully")
  end

  # POST /api/v1/automation_enrollments/:id/pause
  def pause
    reason = params[:reason] || "Paused via API"

    if @enrollment.pause!(reason)
      render_success(
        enrollment: serialize_enrollment_detail(@enrollment),
        message: "Enrollment paused successfully"
      )
    else
      render_validation_errors(@enrollment)
    end
  end

  # POST /api/v1/automation_enrollments/:id/resume
  def resume
    if @enrollment.resume!
      render_success(
        enrollment: serialize_enrollment_detail(@enrollment),
        message: "Enrollment resumed successfully"
      )
    else
      render_validation_errors(@enrollment)
    end
  end

  private

  def set_enrollment
    @enrollment = current_account.email_automations
                                .joins(:automation_enrollments)
                                .find_by!(automation_enrollments: { id: params[:id] })
                                .automation_enrollments
                                .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error("Enrollment not found", [], :not_found)
  end

  def automation_service
    @automation_service ||= EmailAutomationService.new(account: current_account)
  end

  def enrollment_params
    params.require(:enrollment).permit(:automation_id, :contact_id, context: {})
  end

  def filter_enrollments(enrollments)
    enrollments = enrollments.select { |e| e.status == params[:status] } if params[:status].present?
    enrollments = enrollments.select { |e| e.email_automation_id == params[:automation_id].to_i } if params[:automation_id].present?
    enrollments = enrollments.select { |e| e.contact.email.downcase.include?(params[:contact_email].downcase) } if params[:contact_email].present?
    enrollments
  end

  def serialize_enrollments(enrollments)
    enrollments.map { |enrollment| serialize_enrollment(enrollment) }
  end

  def serialize_enrollment(enrollment)
    {
      id: enrollment.id,
      automation: {
        id: enrollment.email_automation.id,
        name: enrollment.email_automation.name
      },
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

  def serialize_enrollment_detail(enrollment)
    serialize_enrollment(enrollment).merge(
      context: enrollment.context,
      execution_history: enrollment.execution_history,
      engagement_metrics: enrollment.engagement_during_automation
    )
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
