class CreateAiInsights < ActiveRecord::Migration[7.1]
  def change
    create_table :ai_insights do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_provider, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.references :insightable, polymorphic: true, null: true
      t.string :insight_type, null: false
      t.string :title, null: false
      t.text :content, null: false
      t.integer :confidence_score, null: false
      t.string :priority, default: 'medium'
      t.string :status, default: 'pending'
      t.json :metadata
      t.datetime :implemented_at
      t.datetime :dismissed_at
      t.text :implementation_notes
      t.text :dismissal_reason

      t.timestamps
    end

    add_index :ai_insights, [:account_id, :insight_type]
    add_index :ai_insights, [:account_id, :status]
    add_index :ai_insights, [:account_id, :priority]
    add_index :ai_insights, [:account_id, :created_at]
    add_index :ai_insights, [:insightable_type, :insightable_id]
    add_index :ai_insights, [:confidence_score]
  end
end