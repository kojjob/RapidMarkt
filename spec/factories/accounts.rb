FactoryBot.define do
  factory :account do
    sequence(:name) { |n| "Test Account #{n}" }
    sequence(:subdomain) { |n| "test-account-#{n}" }
    plan { "free" }
    status { "active" }
  end
end
