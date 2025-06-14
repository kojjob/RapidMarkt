class AddMediaSupportToCampaigns < ActiveRecord::Migration[8.0]
  def change
    add_column :campaigns, :media_type, :string, default: 'text'
    add_column :campaigns, :media_urls, :text
    add_column :campaigns, :social_platforms, :text
    add_column :campaigns, :design_theme, :string, default: 'modern'
    add_column :campaigns, :background_color, :string, default: '#ffffff'
    add_column :campaigns, :text_color, :string, default: '#1f2937'
    add_column :campaigns, :font_family, :string, default: 'Inter'
    add_column :campaigns, :header_image_url, :string
    add_column :campaigns, :logo_url, :string
    add_column :campaigns, :call_to_action_text, :string
    add_column :campaigns, :call_to_action_url, :string
    add_column :campaigns, :social_sharing_enabled, :boolean, default: false
  end
end
