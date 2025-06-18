class AiBulkContentGenerationJob < ApplicationJob
  queue_as :ai_bulk_operations
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  
  def perform(content_generation_ids, user_id = nil)
    user = User.find(user_id) if user_id
    content_generations = ContentGeneration.where(id: content_generation_ids)
    
    total_count = content_generations.count
    completed_count = 0
    failed_count = 0
    
    # Update all to processing status
    content_generations.update_all(
      status: 'processing',
      started_at: Time.current
    )
    
    # Broadcast initial status
    broadcast_progress(user, 0, total_count, 0) if user
    
    content_generations.find_each do |content_generation|
      begin
        # Process each content generation individually
        AiContentGenerationJob.perform_now(content_generation.id, user_id)
        completed_count += 1
        
        # Broadcast progress update
        broadcast_progress(user, completed_count, total_count, failed_count) if user
        
        # Add small delay to respect rate limits
        sleep(0.5) if content_generations.count > 1
        
      rescue => error
        failed_count += 1
        Rails.logger.error "Bulk content generation failed for ID #{content_generation.id}: #{error.message}"
        
        # Update individual record with error
        content_generation.update!(
          status: 'failed',
          error_message: error.message,
          completed_at: Time.current
        )
        
        # Broadcast progress update
        broadcast_progress(user, completed_count, total_count, failed_count) if user
      end
    end
    
    # Broadcast final completion
    if user
      ActionCable.server.broadcast(
        "ai_generation_#{user.id}",
        {
          type: 'bulk_generation_completed',
          total_count: total_count,
          completed_count: completed_count,
          failed_count: failed_count,
          success_rate: (completed_count.to_f / total_count * 100).round(2)
        }
      )
    end
    
    # Log bulk operation
    account = content_generations.first&.account
    if account
      AiUsageLog.create!(
        account: account,
        operation_type: 'bulk_content_generation',
        success: failed_count == 0,
        metadata: {
          total_count: total_count,
          completed_count: completed_count,
          failed_count: failed_count,
          user_id: user_id
        }
      )
    end
  end
  
  private
  
  def broadcast_progress(user, completed, total, failed)
    return unless user
    
    progress_percentage = (completed.to_f / total * 100).round(2)
    
    ActionCable.server.broadcast(
      "ai_generation_#{user.id}",
      {
        type: 'bulk_generation_progress',
        completed_count: completed,
        total_count: total,
        failed_count: failed,
        progress_percentage: progress_percentage
      }
    )
  end
end