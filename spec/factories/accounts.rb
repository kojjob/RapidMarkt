FactoryBot.define do
  factory :account do
    name { "Test Account" }
    subdomain { Faker::Internet.domain_word.downcase }
    plan { "free" }
    status { "active" }
  end
end
