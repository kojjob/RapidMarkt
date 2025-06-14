class CreateCampaigns < ActiveRecord::Migration[8.0]
  def change
    create_table :campaigns do |t|
      t.references :account, null: false, foreign_key: true
      t.string :name
      t.string :subject
      t.string :status
      t.datetime :scheduled_at
      t.datetime :sent_at
      t.decimal :open_rate
      t.decimal :click_rate

      t.timestamps
    end
  end
end
