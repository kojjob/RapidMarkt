class RemoveTagsFromContacts < ActiveRecord::Migration[8.0]
  def change
    remove_column :contacts, :tags, :text
  end
end
