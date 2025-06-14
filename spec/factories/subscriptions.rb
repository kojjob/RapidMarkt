FactoryBot.define do
  factory :subscription do
    account { nil }
    stripe_subscription_id { "MyString" }
    stripe_customer_id { "MyString" }
    plan_name { "MyString" }
    status { "MyString" }
    current_period_start { "2025-06-14 12:54:41" }
    current_period_end { "2025-06-14 12:54:41" }
    trial_end { "2025-06-14 12:54:41" }
  end
end
