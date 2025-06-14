class AddOnboardingFieldsToAccounts < ActiveRecord::Migration[8.0]
  def change
    add_column :accounts, :business_type, :string
    add_column :accounts, :website, :string
    add_column :accounts, :industry, :string
  end
end
