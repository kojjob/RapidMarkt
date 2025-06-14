class CreateContactTags < ActiveRecord::Migration[8.0]
  def change
    create_table :contact_tags do |t|
      t.references :contact, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true

      t.timestamps
    end
  end
end
