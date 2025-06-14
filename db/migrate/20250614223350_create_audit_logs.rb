class CreateAuditLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :audit_logs do |t|
      t.references :user, null: false, foreign_key: true
      t.string :action, null: false
      t.jsonb :details, default: {}
      t.string :ip_address
      t.text :user_agent
      t.datetime :performed_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.string :resource_type
      t.bigint :resource_id

      t.timestamps
    end
    
    add_index :audit_logs, :action
    add_index :audit_logs, :performed_at
    add_index :audit_logs, [:user_id, :action]
    add_index :audit_logs, [:resource_type, :resource_id]
    add_index :audit_logs, :details, using: :gin
  end
end
