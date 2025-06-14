class CreateAccounts < ActiveRecord::Migration[8.0]
  def change
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :plan, default: 'free'
      t.string :status, default: 'active'
      t.text :settings

      t.timestamps
    end

    add_index :accounts, :subdomain, unique: true
    add_index :accounts, :status
  end
end
