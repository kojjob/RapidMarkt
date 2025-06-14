class AddLastOpenedAtToContacts < ActiveRecord::Migration[8.0]
  def change
    add_column :contacts, :last_opened_at, :datetime
  end
end
