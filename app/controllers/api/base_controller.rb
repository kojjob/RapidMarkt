# frozen_string_literal: true

class Api::BaseController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :authenticate_api_user!

  respond_to :json

  protected

  def authenticate_api_user!
    # For now, use session-based auth. In production, implement API tokens
    authenticate_user!
  end

  def render_success(data = {}, message = nil, status = :ok)
    response = { success: true }
    response[:data] = data if data.present?
    response[:message] = message if message.present?
    render json: response, status: status
  end

  def render_error(message, errors = [], status = :unprocessable_entity)
    render json: {
      success: false,
      message: message,
      errors: errors
    }, status: status
  end

  def render_validation_errors(resource)
    render_error(
      "Validation failed",
      resource.errors.full_messages,
      :unprocessable_entity
    )
  end
end
