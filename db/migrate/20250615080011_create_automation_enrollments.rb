class CreateAutomationEnrollments < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_enrollments do |t|
      t.references :email_automation, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :status, null: false, default: 'active'
      t.timestamp :enrolled_at, null: false
      t.integer :current_step, default: 1
      t.timestamp :completed_at
      t.timestamp :paused_at
      t.timestamp :dropped_at
      t.timestamp :failed_at
      t.jsonb :context, default: {}
      t.string :pause_reason
      t.string :drop_reason
      t.text :error_message
      t.timestamp :last_activity_at
      t.integer :activity_count, default: 0
      t.decimal :engagement_score, precision: 5, scale: 2
      t.jsonb :tracking_data, default: {}

      t.timestamps
    end

    add_index :automation_enrollments, :email_automation_id, if_not_exists: true
    add_index :automation_enrollments, :contact_id, if_not_exists: true
    add_index :automation_enrollments, :status, if_not_exists: true
    add_index :automation_enrollments, :enrolled_at, if_not_exists: true
    add_index :automation_enrollments, :last_activity_at, if_not_exists: true
    add_index :automation_enrollments, :engagement_score, if_not_exists: true
    add_index :automation_enrollments, [:email_automation_id, :contact_id], 
              name: 'index_automation_enrollments_on_automation_and_contact', if_not_exists: true
    add_index :automation_enrollments, [:email_automation_id, :status], if_not_exists: true
    add_index :automation_enrollments, :context, using: :gin, if_not_exists: true
    add_index :automation_enrollments, :tracking_data, using: :gin, if_not_exists: true

    # Unique constraint to prevent duplicate active/paused enrollments
    add_index :automation_enrollments, [:email_automation_id, :contact_id], 
              unique: true, 
              where: "status IN ('active', 'paused')",
              name: 'index_unique_active_automation_enrollments', if_not_exists: true
  end
end
