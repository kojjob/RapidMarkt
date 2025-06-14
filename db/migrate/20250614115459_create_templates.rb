class CreateTemplates < ActiveRecord::Migration[8.0]
  def change
    create_table :templates do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.string :subject
      t.text :body
      t.string :template_type
      t.string :status

      t.timestamps
    end
  end
end
