class CreateOnboardingProgresses < ActiveRecord::Migration[8.0]
  def change
    create_table :onboarding_progresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :current_step, null: false, default: 'welcome'
      t.boolean :completed, default: false, null: false
      t.datetime :completed_at
      t.datetime :started_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.integer :completion_percentage, default: 0, null: false
      t.float :total_time_minutes, default: 0.0
      t.jsonb :completed_steps, default: {}

      t.timestamps
    end
    
    add_index :onboarding_progresses, :user_id, unique: true unless index_exists?(:onboarding_progresses, :user_id)
    add_index :onboarding_progresses, :current_step
    add_index :onboarding_progresses, :completed
    add_index :onboarding_progresses, :completed_steps, using: :gin
  end
end
