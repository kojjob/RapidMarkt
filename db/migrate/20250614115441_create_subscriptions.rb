class CreateSubscriptions < ActiveRecord::Migration[8.0]
  def change
    create_table :subscriptions do |t|
      t.references :account, null: false, foreign_key: true
      t.string :stripe_subscription_id
      t.string :stripe_customer_id
      t.string :plan_name
      t.string :status
      t.datetime :current_period_start
      t.datetime :current_period_end
      t.datetime :trial_end

      t.timestamps
    end
  end
end
