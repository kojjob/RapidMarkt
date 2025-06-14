class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.references :account, null: false, foreign_key: true
      t.string :email
      t.string :first_name
      t.string :last_name
      t.string :status
      t.datetime :subscribed_at
      t.datetime :unsubscribed_at
      t.text :tags

      t.timestamps
    end
  end
end
