class CreateAutomationSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :automation_steps do |t|
      t.references :email_automation, null: false, foreign_key: true
      t.string :step_type, null: false
      t.integer :step_order, null: false
      t.integer :delay_amount, null: false, default: 0
      t.string :delay_unit, null: false, default: 'hours'
      t.integer :email_template_id
      t.string :custom_subject
      t.text :custom_body
      t.jsonb :conditions, default: {}

      t.timestamps
    end

    add_index :automation_steps, :email_automation_id, if_not_exists: true
    add_index :automation_steps, :step_type, if_not_exists: true
    add_index :automation_steps, :email_template_id, if_not_exists: true
    add_index :automation_steps, [ :email_automation_id, :step_order ], unique: true, if_not_exists: true
    add_index :automation_steps, :conditions, using: :gin, if_not_exists: true

    add_foreign_key :automation_steps, :templates, column: :email_template_id, if_not_exists: true
  end
end
