class BrandVoiceService
  def initialize(brand_voice)
    @brand_voice = brand_voice
  end

  def apply_voice(content)
    return content if content.blank? || @brand_voice.blank?

    transformed_content = content.dup

    # Apply transformations in order
    transformed_content = apply_tone_adjustments(transformed_content)
    transformed_content = apply_vocabulary_preferences(transformed_content)
    transformed_content = apply_writing_style_rules(transformed_content)
    transformed_content = apply_personality_traits(transformed_content)

    transformed_content
  end

  def analyze_content_compatibility(content)
    return { score: 0, suggestions: [] } if content.blank?

    score = calculate_voice_compatibility_score(content)
    suggestions = generate_improvement_suggestions(content)

    {
      score: score,
      suggestions: suggestions,
      tone_match: analyze_tone_match(content),
      vocabulary_match: analyze_vocabulary_match(content)
    }
  end

  private

  def apply_tone_adjustments(content)
    case @brand_voice.tone
    when "friendly"
      content.gsub(/\bDear\b/, "Hi")
             .gsub(/\bSincerely\b/, "Cheers")
             .gsub(/\bRegards\b/, "Best wishes")
    when "professional"
      content.gsub(/\bHey\b/, "Dear")
             .gsub(/\bCheers\b/, "Best regards")
             .gsub(/\bThanks\b/, "Thank you")
    when "casual"
      content.gsub(/\bDear\b/, "Hey")
             .gsub(/\bSincerely\b/, "Thanks")
             .gsub(/\bRegards\b/, "Cheers")
    when "authoritative"
      content.gsub(/\bI think\b/, "I recommend")
             .gsub(/\bmaybe\b/, "likely")
             .gsub(/\bmight\b/, "will")
    when "playful"
      content.gsub(/\bHello\b/, "Hey there!")
             .gsub(/\bGoodbye\b/, "See ya!")
    when "empathetic"
      content.gsub(/\bI understand\b/, "I completely understand")
             .gsub(/\bSorry\b/, "I'm truly sorry")
    when "confident"
      content.gsub(/\bI believe\b/, "I know")
             .gsub(/\bprobably\b/, "definitely")
    else
      content
    end
  end

  def apply_vocabulary_preferences(content)
    preferences = @brand_voice.vocabulary_preferences_hash

    # Replace with preferred words
    if preferences["preferred_words"].present?
      preferences["preferred_words"].each do |replacement|
        next unless replacement.is_a?(Hash) && replacement["from"] && replacement["to"]

        content = content.gsub(/\b#{Regexp.escape(replacement['from'])}\b/i, replacement["to"])
      end
    end

    # Apply emoji preferences
    case preferences["emoji_usage"]
    when "high"
      content = add_emojis_to_content(content)
    when "low"
      content = remove_emojis_from_content(content)
    when "none"
      content = content.gsub(/[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]/, "")
    end

    content
  end

  def apply_writing_style_rules(content)
    rules = @brand_voice.writing_style_rules_list

    rules.each do |rule|
      case rule["type"]
      when "sentence_length"
        content = adjust_sentence_length(content, rule["preference"])
      when "punctuation_style"
        content = adjust_punctuation_style(content, rule["style"])
      when "paragraph_structure"
        content = adjust_paragraph_structure(content, rule["structure"])
      end
    end

    content
  end

  def apply_personality_traits(content)
    traits = @brand_voice.personality_traits_list

    traits.each do |trait|
      case trait
      when "enthusiastic"
        content = content.gsub(/\./, "!")
      when "helpful"
        content = content.gsub(/\bYou should\b/, "You might want to")
      when "expert"
        content = add_expert_language(content)
      when "approachable"
        content = make_content_more_approachable(content)
      end
    end

    content
  end

  def calculate_voice_compatibility_score(content)
    # Simple scoring algorithm - can be enhanced with ML
    score = 50 # Base score

    # Check tone compatibility
    tone_words = get_tone_words(@brand_voice.tone)
    tone_matches = tone_words.count { |word| content.downcase.include?(word) }
    score += (tone_matches * 10)

    # Check vocabulary preferences
    preferences = @brand_voice.vocabulary_preferences_hash
    if preferences["avoid_words"].present?
      avoid_matches = preferences["avoid_words"].count { |word| content.downcase.include?(word.downcase) }
      score -= (avoid_matches * 15)
    end

    [ score, 100 ].min
  end

  def generate_improvement_suggestions(content)
    suggestions = []

    # Tone suggestions
    if @brand_voice.tone == "friendly" && !content.match?(/hi|hello|hey/i)
      suggestions << "Consider using a friendlier greeting like 'Hi' or 'Hello'"
    end

    # Vocabulary suggestions
    preferences = @brand_voice.vocabulary_preferences_hash
    if preferences["avoid_words"].present?
      avoid_words_found = preferences["avoid_words"].select { |word| content.downcase.include?(word.downcase) }
      if avoid_words_found.any?
        suggestions << "Consider avoiding these words: #{avoid_words_found.join(', ')}"
      end
    end

    suggestions
  end

  def analyze_tone_match(content)
    tone_words = get_tone_words(@brand_voice.tone)
    matches = tone_words.count { |word| content.downcase.include?(word) }

    {
      expected_tone: @brand_voice.tone,
      matches_found: matches,
      percentage: (matches.to_f / tone_words.length * 100).round(2)
    }
  end

  def analyze_vocabulary_match(content)
    preferences = @brand_voice.vocabulary_preferences_hash
    preferred_found = preferences["preferred_words"]&.count { |word| content.downcase.include?(word["from"]&.downcase || "") } || 0
    avoided_found = preferences["avoid_words"]&.count { |word| content.downcase.include?(word.downcase) } || 0

    {
      preferred_words_used: preferred_found,
      avoided_words_found: avoided_found,
      vocabulary_score: [ 100 - (avoided_found * 20), 0 ].max
    }
  end

  def get_tone_words(tone)
    case tone
    when "friendly"
      %w[hi hello hey thanks please wonderful great amazing]
    when "professional"
      %w[dear sincerely regards thank you please consider]
    when "casual"
      %w[hey cool awesome yeah sure no problem]
    when "authoritative"
      %w[recommend must should will definitely ensure]
    when "playful"
      %w[fun exciting awesome cool amazing fantastic]
    when "empathetic"
      %w[understand feel sorry care support help]
    when "confident"
      %w[know certain sure definitely will guarantee]
    else
      []
    end
  end

  def add_emojis_to_content(content)
    # Simple emoji addition - can be enhanced
    content.gsub(/!/, "! 😊")
           .gsub(/\bthanks\b/i, "thanks 🙏")
           .gsub(/\bgreat\b/i, "great 👍")
  end

  def remove_emojis_from_content(content)
    content.gsub(/[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]/, "")
  end

  def adjust_sentence_length(content, preference)
    # Implementation for sentence length adjustment
    content
  end

  def adjust_punctuation_style(content, style)
    case style
    when "enthusiastic"
      content.gsub(/\./, "!")
    when "minimal"
      content.gsub(/!+/, ".")
    else
      content
    end
  end

  def adjust_paragraph_structure(content, structure)
    # Implementation for paragraph structure adjustment
    content
  end

  def add_expert_language(content)
    # Add more authoritative language
    content.gsub(/\bI think\b/, "Based on my experience")
           .gsub(/\bmaybe\b/, "typically")
  end

  def make_content_more_approachable(content)
    # Make language more accessible
    content.gsub(/\butilize\b/, "use")
           .gsub(/\bfacilitate\b/, "help")
           .gsub(/\bimplement\b/, "set up")
  end
end
