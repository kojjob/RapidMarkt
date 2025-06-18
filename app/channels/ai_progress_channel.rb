class AiProgressChannel < ApplicationCable::Channel
  def subscribed
    # Subscribe to AI progress updates for the current account
    stream_from "ai_progress_#{current_account.id}"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end

  def subscribe_to_generation(data)
    # Subscribe to specific content generation updates
    generation_id = data['generation_id']
    if generation_id.present?
      stream_from "ai_generation_#{generation_id}"
    end
  end

  def subscribe_to_bulk_operation(data)
    # Subscribe to bulk operation updates
    job_id = data['job_id']
    if job_id.present?
      stream_from "ai_bulk_#{job_id}"
    end
  end
end