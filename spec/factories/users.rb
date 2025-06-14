FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "password123" }
    password_confirmation { "password123" }
    first_name { "John" }
    last_name { "Doe" }
    role { "member" }
    association :account

    trait :owner do
      role { "owner" }
    end

    trait :admin do
      role { "admin" }
    end
  end
end
