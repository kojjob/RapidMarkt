FactoryBot.define do
  factory :brand_voice do
    account { nil }
    name { "MyString" }
    tone { "MyString" }
    personality_traits { "MyText" }
    vocabulary_preferences { "MyText" }
    writing_style_rules { "MyText" }
    description { "MyText" }
  end
end
