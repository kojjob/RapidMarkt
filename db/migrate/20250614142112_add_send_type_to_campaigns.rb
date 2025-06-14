class AddSendTypeToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :send_type, :string, default: 'now'
  end
end
