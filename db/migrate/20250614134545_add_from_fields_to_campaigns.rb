class AddFromFieldsToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :from_name, :string
    add_column :campaigns, :from_email, :string
  end
end
