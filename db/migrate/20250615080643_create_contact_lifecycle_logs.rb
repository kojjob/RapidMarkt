class CreateContactLifecycleLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :contact_lifecycle_logs do |t|
      t.references :contact, null: false, foreign_key: true
      t.string :from_stage
      t.string :to_stage, null: false
      t.text :reason
      t.references :user, null: true, foreign_key: true

      t.timestamps
    end

    add_index :contact_lifecycle_logs, :contact_id, if_not_exists: true
    add_index :contact_lifecycle_logs, :from_stage, if_not_exists: true
    add_index :contact_lifecycle_logs, :to_stage, if_not_exists: true
    add_index :contact_lifecycle_logs, :created_at, if_not_exists: true
    add_index :contact_lifecycle_logs, [ :contact_id, :created_at ], if_not_exists: true
  end
end
