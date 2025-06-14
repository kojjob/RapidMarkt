class CreateCampaignContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_contacts do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.datetime :sent_at
      t.datetime :opened_at
      t.datetime :clicked_at
      t.datetime :bounced_at
      t.datetime :unsubscribed_at

      t.timestamps
    end
  end
end
