class AddCompanyFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :company_name, :string
    add_column :accounts, :phone, :string
    add_column :accounts, :address, :string
    add_column :accounts, :city, :string
    add_column :accounts, :state, :string
    add_column :accounts, :zip_code, :string
    add_column :accounts, :country, :string
  end
end
