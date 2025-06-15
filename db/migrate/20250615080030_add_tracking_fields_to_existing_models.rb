class AddTrackingFieldsToExistingModels < ActiveRecord::Migration[8.0]
  def change
    # Add tracking fields to campaigns
    add_column :campaigns, :last_activity_at, :timestamp
    add_column :campaigns, :activity_count, :integer, default: 0
    add_column :campaigns, :engagement_score, :decimal, precision: 5, scale: 2
    add_column :campaigns, :tracking_data, :jsonb, default: {}
    add_column :campaigns, :automation_step_id, :integer
    add_column :campaigns, :automation_execution_id, :integer

    # Add tracking fields to templates
    add_column :templates, :last_activity_at, :timestamp
    add_column :templates, :activity_count, :integer, default: 0
    add_column :templates, :engagement_score, :decimal, precision: 5, scale: 2
    add_column :templates, :tracking_data, :jsonb, default: {}
    add_column :templates, :design_config, :jsonb, default: {}
    add_column :templates, :ab_test_enabled, :boolean, default: false
    add_column :templates, :ab_test_original_id, :integer

    # Add tracking fields to contacts
    add_column :contacts, :last_activity_at, :timestamp
    add_column :contacts, :activity_count, :integer, default: 0
    add_column :contacts, :engagement_score, :decimal, precision: 5, scale: 2
    add_column :contacts, :tracking_data, :jsonb, default: {}
    add_column :contacts, :lifecycle_stage, :string, default: 'lead'
    add_column :contacts, :lifecycle_updated_at, :timestamp
    add_column :contacts, :value_score, :decimal, precision: 5, scale: 2
    add_column :contacts, :last_enriched_at, :timestamp
    add_column :contacts, :unsubscribe_token, :string
    add_column :contacts, :email_frequency, :string, default: 'normal'
    add_column :contacts, :preferred_content_types, :jsonb, default: []
    add_column :contacts, :preferred_channels, :jsonb, default: []
    add_column :contacts, :custom_fields, :jsonb, default: {}

    # Add tracking fields to accounts
    add_column :accounts, :last_activity_at, :timestamp
    add_column :accounts, :activity_count, :integer, default: 0
    add_column :accounts, :engagement_score, :decimal, precision: 5, scale: 2
    add_column :accounts, :tracking_data, :jsonb, default: {}

    # Add indexes for performance
    add_index :campaigns, :last_activity_at, if_not_exists: true
    add_index :campaigns, :engagement_score, if_not_exists: true
    add_index :campaigns, :automation_step_id, if_not_exists: true
    add_index :campaigns, :automation_execution_id, if_not_exists: true
    add_index :campaigns, :tracking_data, using: :gin, if_not_exists: true

    add_index :templates, :last_activity_at, if_not_exists: true
    add_index :templates, :engagement_score, if_not_exists: true
    add_index :templates, :ab_test_original_id, if_not_exists: true
    add_index :templates, :design_config, using: :gin, if_not_exists: true
    add_index :templates, :tracking_data, using: :gin, if_not_exists: true

    add_index :contacts, :last_activity_at, if_not_exists: true
    add_index :contacts, :engagement_score, if_not_exists: true
    add_index :contacts, :lifecycle_stage, if_not_exists: true
    add_index :contacts, :value_score, if_not_exists: true
    add_index :contacts, :unsubscribe_token, unique: true, if_not_exists: true
    add_index :contacts, :email_frequency, if_not_exists: true
    add_index :contacts, :tracking_data, using: :gin, if_not_exists: true
    add_index :contacts, :preferred_content_types, using: :gin, if_not_exists: true
    add_index :contacts, :custom_fields, using: :gin, if_not_exists: true

    add_index :accounts, :last_activity_at, if_not_exists: true
    add_index :accounts, :engagement_score, if_not_exists: true
    add_index :accounts, :tracking_data, using: :gin, if_not_exists: true

    # Add foreign key constraints
    add_foreign_key :campaigns, :automation_steps, column: :automation_step_id, if_not_exists: true
    add_foreign_key :campaigns, :automation_executions, column: :automation_execution_id, if_not_exists: true
    add_foreign_key :templates, :templates, column: :ab_test_original_id, if_not_exists: true
  end
end
