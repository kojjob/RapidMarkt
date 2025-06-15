class BrandVoice < ApplicationRecord
  belongs_to :account
  
  validates :name, presence: true, length: { maximum: 100 }
  validates :tone, presence: true
  validates :description, length: { maximum: 500 }
  
  # Tone options for different communication styles
  enum tone: {
    friendly: 'friendly',
    professional: 'professional',
    casual: 'casual',
    authoritative: 'authoritative',
    playful: 'playful',
    empathetic: 'empathetic',
    confident: 'confident'
  }
  
  # Serialize JSON fields for complex data structures
  serialize :personality_traits, coder: JSON
  serialize :vocabulary_preferences, coder: JSON
  serialize :writing_style_rules, coder: JSON
  
  # Default values for JSON fields
  after_initialize :set_defaults
  
  scope :by_tone, ->(tone) { where(tone: tone) }
  scope :for_account, ->(account) { where(account: account) }
  
  def apply_to_content(content)
    BrandVoiceService.new(self).apply_voice(content)
  end
  
  def personality_traits_list
    personality_traits || []
  end
  
  def vocabulary_preferences_hash
    vocabulary_preferences || {}
  end
  
  def writing_style_rules_list
    writing_style_rules || []
  end
  
  private
  
  def set_defaults
    self.personality_traits ||= []
    self.vocabulary_preferences ||= {
      'preferred_words' => [],
      'avoid_words' => [],
      'emoji_usage' => 'moderate'
    }
    self.writing_style_rules ||= []
  end
end
