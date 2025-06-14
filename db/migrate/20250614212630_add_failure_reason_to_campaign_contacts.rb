class AddFailureReasonToCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :campaign_contacts, :failure_reason, :text
  end
end
