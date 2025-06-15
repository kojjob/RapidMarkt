class CreateAutomationExecutions < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_executions do |t|
      t.references :automation_enrollment, null: false, foreign_key: true
      t.references :automation_step, null: false, foreign_key: true
      t.string :status, null: false, default: 'scheduled'
      t.timestamp :scheduled_at, null: false
      t.timestamp :started_at
      t.timestamp :executed_at
      t.timestamp :cancelled_at
      t.text :error_message
      t.jsonb :error_details, default: {}
      t.jsonb :execution_data, default: {}
      t.integer :retry_count, default: 0

      t.timestamps
    end

    add_index :automation_executions, :automation_enrollment_id, if_not_exists: true
    add_index :automation_executions, :automation_step_id, if_not_exists: true
    add_index :automation_executions, :status, if_not_exists: true
    add_index :automation_executions, :scheduled_at, if_not_exists: true
    add_index :automation_executions, :executed_at, if_not_exists: true
    add_index :automation_executions, [ :status, :scheduled_at ], if_not_exists: true
    add_index :automation_executions, :error_details, using: :gin, if_not_exists: true
    add_index :automation_executions, :execution_data, using: :gin, if_not_exists: true

    # Index for finding due executions efficiently
    add_index :automation_executions, [ :scheduled_at, :status ],
              where: "status = 'scheduled'",
              name: 'index_automation_executions_due_for_execution', if_not_exists: true
  end
end
