class AddIndexesForPerformance < ActiveRecord::Migration[8.0]
  def change
    # Add indexes for frequently queried status columns
    add_index :contacts, :status
    add_index :campaigns, :status
    add_index :templates, :status
    
    # Add index for contact email searches and uniqueness
    add_index :contacts, :email
    
    # Add indexes for frequently queried date columns
    add_index :campaigns, :scheduled_at
    add_index :campaigns, :sent_at
    add_index :contacts, :subscribed_at
  end
end
