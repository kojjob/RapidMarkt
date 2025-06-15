class AddBrandVoiceToTemplates < ActiveRecord::Migration[8.0]
  def change
    add_reference :templates, :brand_voice, null: true, foreign_key: true
  end
end
