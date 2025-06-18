FactoryBot.define do
  factory :brand_voice do
    account
    name { "Professional Voice" }
    tone { "professional" }
    personality_traits { ["Confident", "knowledgeable", "approachable"] }
    vocabulary_preferences {
      {
        "preferred_words" => [
          { "from" => "good", "to" => "excellent" },
          { "from" => "nice", "to" => "outstanding" },
          { "from" => "great", "to" => "remarkable" }
        ],
        "avoid_words" => ["bad", "terrible", "awful"],
        "emoji_usage" => "moderate"
      }
    }
    writing_style_rules { { "sentence_length" => "short", "voice" => "active", "formatting" => "bullet_points" } }
    description { "A professional brand voice for business communications" }
  end
end
