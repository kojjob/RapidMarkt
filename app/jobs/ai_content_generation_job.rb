class AiContentGenerationJob < ApplicationJob
  queue_as :ai_operations
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Net::TimeoutError, wait: 30.seconds, attempts: 5
  
  def perform(content_generation_id, user_id = nil)
    content_generation = ContentGeneration.find(content_generation_id)
    user = User.find(user_id) if user_id
    
    # Update status to processing
    content_generation.update!(status: 'processing', started_at: Time.current)
    
    begin
      ai_service = AiService.new(content_generation.account)
      
      case content_generation.content_type
      when 'email_subject'
        result = ai_service.generate_email_subject(
          content_generation.prompt,
          content_generation.context
        )
      when 'email_body'
        result = ai_service.generate_email_body(
          content_generation.prompt,
          content_generation.context
        )
      when 'campaign_content'
        result = ai_service.generate_campaign_content(
          content_generation.prompt,
          content_generation.context
        )
      else
        result = ai_service.generate_content(
          content_generation.prompt,
          content_generation.context
        )
      end
      
      # Update with successful result
      content_generation.update!(
        status: 'completed',
        generated_content: result[:content],
        tokens_used: result[:tokens_used],
        cost: result[:cost],
        provider_used: result[:provider],
        completed_at: Time.current,
        error_message: nil
      )
      
      # Log usage
      AiUsageLog.create!(
        account: content_generation.account,
        ai_provider: result[:ai_provider],
        operation_type: 'content_generation',
        tokens_used: result[:tokens_used],
        cost: result[:cost],
        success: true,
        response_time_ms: result[:response_time_ms],
        metadata: {
          content_generation_id: content_generation.id,
          content_type: content_generation.content_type,
          user_id: user_id
        }
      )
      
      # Broadcast completion to user if present
      if user
        ActionCable.server.broadcast(
          "ai_generation_#{user.id}",
          {
            type: 'content_generation_completed',
            content_generation_id: content_generation.id,
            status: 'completed',
            content: result[:content]
          }
        )
      end
      
    rescue => error
      # Update with error status
      content_generation.update!(
        status: 'failed',
        error_message: error.message,
        completed_at: Time.current
      )
      
      # Log failed usage
      AiUsageLog.create!(
        account: content_generation.account,
        operation_type: 'content_generation',
        success: false,
        error_message: error.message,
        metadata: {
          content_generation_id: content_generation.id,
          content_type: content_generation.content_type,
          user_id: user_id
        }
      )
      
      # Broadcast error to user if present
      if user
        ActionCable.server.broadcast(
          "ai_generation_#{user.id}",
          {
            type: 'content_generation_failed',
            content_generation_id: content_generation.id,
            status: 'failed',
            error: error.message
          }
        )
      end
      
      # Re-raise for retry logic
      raise error
    end
  end
end