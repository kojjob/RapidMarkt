FactoryBot.define do
  factory :account do
    name { "Test Account" }
    subdomain { "test-account" }
    plan { "free" }
    status { "active" }
  end
end
