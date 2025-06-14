class AddAccountToUsers < ActiveRecord::Migration[8.0]
  def change
    add_reference :users, :account, null: false, foreign_key: true
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :role, :string, default: 'member'
  end
end
