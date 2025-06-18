class UpdateContentGenerationsForBackgroundJobs < ActiveRecord::Migration[7.1]
  def change
    # Add new status values for background job processing
    # The existing status column already exists, we just need to ensure it supports the new values
    
    # Add progress tracking fields
    add_column :content_generations, :progress_percentage, :integer, default: 0
    add_column :content_generations, :error_message, :text
    add_column :content_generations, :retry_count, :integer, default: 0
    add_column :content_generations, :job_id, :string
    add_column :content_generations, :started_at, :datetime
    add_column :content_generations, :completed_at, :datetime
    
    # Add indexes for better query performance
    add_index :content_generations, :status, if_not_exists: true
    add_index :content_generations, :job_id, if_not_exists: true
    add_index :content_generations, [:account_id, :created_at], if_not_exists: true
  end
end