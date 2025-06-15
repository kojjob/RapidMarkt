FactoryBot.define do
  factory :contact do
    account { nil }
    email { "MyString" }
    first_name { "MyString" }
    last_name { "MyString" }
    status { "MyString" }
    subscribed_at { "2025-06-14 12:54:53" }
    unsubscribed_at { "2025-06-14 12:54:53" }
    tags { "MyText" }
  end
end
