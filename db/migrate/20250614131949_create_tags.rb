class CreateTags < ActiveRecord::Migration[8.0]
  def change
    create_table :tags do |t|
      t.string :name
      t.string :color
      t.text :description
      t.references :account, null: false, foreign_key: true

      t.timestamps
    end
  end
end
