FactoryBot.define do
  factory :user do
    email { "test@example.com" }
    password { "password123" }
    first_name { "John" }
    last_name { "Doe" }
    role { "member" }
    account
  end
end
