FactoryBot.define do
  factory :campaign do
    account { nil }
    name { "MyString" }
    subject { "MyString" }
    status { "MyString" }
    scheduled_at { "2025-06-14 12:54:47" }
    sent_at { "2025-06-14 12:54:47" }
    open_rate { "9.99" }
    click_rate { "9.99" }
  end
end
