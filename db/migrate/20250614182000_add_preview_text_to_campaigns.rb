class AddPreviewTextToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :preview_text, :text
  end
end
