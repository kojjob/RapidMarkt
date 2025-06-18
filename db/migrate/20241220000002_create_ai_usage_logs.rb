class CreateAiUsageLogs < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_usage_logs do |t|
      t.references :ai_provider, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :loggable, polymorphic: true, null: true
      t.string :operation_type, null: false
      t.string :model_used, null: false
      t.integer :tokens_used, null: false
      t.decimal :response_time_ms, precision: 10, scale: 2, null: false
      t.decimal :cost, precision: 10, scale: 6, null: false
      t.boolean :success, default: true
      t.json :request_metadata
      t.json :response_metadata
      t.text :error_message

      t.timestamps
    end

    add_index :ai_usage_logs, [:account_id, :created_at]
    add_index :ai_usage_logs, [:ai_provider_id, :created_at]
    add_index :ai_usage_logs, [:operation_type, :created_at]
    add_index :ai_usage_logs, [:loggable_type, :loggable_id]
    add_index :ai_usage_logs, [:success, :created_at]
  end
end