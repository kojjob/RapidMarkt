class CreateContentGenerations < ActiveRecord::Migration[7.1]
  def change
    create_table :content_generations do |t|
      t.references :account, null: false, foreign_key: true
      t.references :ai_provider, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.references :generatable, polymorphic: true, null: true
      t.string :content_type, null: false
      t.text :prompt, null: false
      t.text :generated_content, null: false
      t.string :status, default: 'draft'
      t.integer :quality_score
      t.integer :performance_score
      t.json :performance_metrics
      t.json :metadata
      t.datetime :approved_at
      t.integer :approved_by
      t.datetime :rejected_at
      t.text :rejection_reason
      t.datetime :published_at

      t.timestamps
    end

    add_index :content_generations, [:account_id, :content_type]
    add_index :content_generations, [:account_id, :status]
    add_index :content_generations, [:account_id, :created_at]
    add_index :content_generations, [:ai_provider_id, :created_at]
    add_index :content_generations, [:generatable_type, :generatable_id]
    add_index :content_generations, [:quality_score]
    add_index :content_generations, [:performance_score]
  end
end