class CreateCampaignTags < ActiveRecord::Migration[8.0]
  def change
    create_table :campaign_tags do |t|
      t.references :campaign, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
    
    add_index :campaign_tags, [:campaign_id, :tag_id], unique: true
  end
end
