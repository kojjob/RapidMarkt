FactoryBot.define do
  factory :campaign do
    association :account
    association :user
    sequence(:name) { |n| "Test Campaign #{n}" }
    sequence(:subject) { |n| "Test Email Subject #{n}" }
    status { "draft" }
    content { "This is test email content" }
    from_name { "Test Sender" }
    from_email { "sender@example.com" }
    reply_to { "reply@example.com" }
    send_type { "now" }
    media_type { "text" }
    design_theme { "modern" }
    font_family { "Inter" }

    trait :scheduled do
      status { "scheduled" }
      scheduled_at { 1.hour.from_now }
    end

    trait :sent do
      status { "sent" }
      sent_at { 1.hour.ago }
      open_rate { 25.5 }
      click_rate { 5.2 }
    end

    trait :sending do
      status { "sending" }
    end
  end
end
