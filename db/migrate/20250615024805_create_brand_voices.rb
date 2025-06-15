class CreateBrandVoices < ActiveRecord::Migration[8.0]
  def change
    create_table :brand_voices do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name, null: false, limit: 100
      t.string :tone, null: false
      t.text :personality_traits
      t.text :vocabulary_preferences
      t.text :writing_style_rules
      t.text :description, limit: 500

      t.timestamps
    end
    
    add_index :brand_voices, [:account_id, :name], unique: true
    add_index :brand_voices, :tone
  end
end
