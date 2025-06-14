class AddRecipientTypeToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :recipient_type, :string
  end
end
