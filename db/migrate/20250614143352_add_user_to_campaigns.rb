class AddUserToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_reference :campaigns, :user, null: true, foreign_key: true
    
    # Update existing campaigns to have a user_id
    # This assumes the first user in each account should own existing campaigns
    reversible do |dir|
      dir.up do
        Campaign.reset_column_information
        Campaign.includes(:account).find_each do |campaign|
          first_user = campaign.account.users.first
          if first_user
            campaign.update_column(:user_id, first_user.id)
          end
        end
        
        # Now make the column non-null
        change_column_null :campaigns, :user_id, false
      end
    end
  end
end
