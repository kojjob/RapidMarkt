class CreateEmailAutomations < ActiveRecord::Migration[8.0]
  def change
    create_table :email_automations do |t|
      t.string :name, null: false
      t.text :description
      t.string :trigger_type, null: false
      t.jsonb :trigger_conditions, default: {}
      t.string :status, null: false, default: 'draft'
      t.references :account, null: false, foreign_key: true
      t.timestamp :activated_at
      t.timestamp :paused_at
      t.timestamp :archived_at
      t.timestamp :last_activity_at
      t.integer :activity_count, default: 0
      t.decimal :engagement_score, precision: 5, scale: 2
      t.jsonb :tracking_data, default: {}
      t.boolean :ab_test_enabled, default: false
      t.integer :ab_test_original_id
      t.integer :ab_test_split_percentage, default: 50

      t.timestamps
    end

    add_index :email_automations, :account_id, if_not_exists: true
    add_index :email_automations, :trigger_type, if_not_exists: true
    add_index :email_automations, :status, if_not_exists: true
    add_index :email_automations, :last_activity_at, if_not_exists: true
    add_index :email_automations, :engagement_score, if_not_exists: true
    add_index :email_automations, :ab_test_original_id, if_not_exists: true
    add_index :email_automations, [:account_id, :status], if_not_exists: true
    add_index :email_automations, [:trigger_type, :status], if_not_exists: true
    add_index :email_automations, :trigger_conditions, using: :gin, if_not_exists: true
    add_index :email_automations, :tracking_data, using: :gin, if_not_exists: true

    add_foreign_key :email_automations, :email_automations, column: :ab_test_original_id, if_not_exists: true
  end
end
