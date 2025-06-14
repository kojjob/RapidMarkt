FactoryBot.define do
  factory :contact do
    association :account
    sequence(:email) { |n| "contact#{n}@example.com" }
    first_name { "Jane" }
    last_name { "Smith" }
    status { "subscribed" }
    subscribed_at { 1.week.ago }

    trait :unsubscribed do
      status { "unsubscribed" }
      unsubscribed_at { 1.day.ago }
    end

    trait :bounced do
      status { "bounced" }
    end
  end
end
