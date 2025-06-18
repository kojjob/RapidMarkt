class CreateAiProviders < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_providers do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false
      t.string :provider_type, null: false
      t.string :api_endpoint, null: false
      t.text :api_key # Will be encrypted
      t.text :api_secret # Will be encrypted
      t.string :status, default: 'active'
      t.string :health_status, default: 'unknown'
      t.integer :priority, default: 0
      t.datetime :last_health_check
      t.text :last_error
      t.json :configuration
      t.json :rate_limits
      t.json :metadata

      t.timestamps
    end

    add_index :ai_providers, [:account_id, :provider_type]
    add_index :ai_providers, [:account_id, :status]
    add_index :ai_providers, [:account_id, :priority]
  end
end