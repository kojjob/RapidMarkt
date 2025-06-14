class OnboardingProgress < ApplicationRecord
  belongs_to :user
  
  # Onboarding steps for indie/SME users - keep it simple!
  ONBOARDING_STEPS = [
    {
      key: 'welcome',
      title: 'Welcome to RapidMarkt! 👋',
      description: 'Let\'s get your marketing automation set up in just a few minutes',
      required: true
    },
    {
      key: 'business_info',
      title: 'Tell us about your business',
      description: 'Help us personalize your experience',
      required: true
    },
    {
      key: 'first_contacts',
      title: 'Add your first contacts',
      description: 'Import your customer list or add contacts manually',
      required: true
    },
    {
      key: 'choose_template',
      title: 'Pick a template',
      description: 'Choose from our indie-friendly email templates',
      required: true
    },
    {
      key: 'first_campaign',
      title: 'Send your first campaign',
      description: 'Let\'s get your first email out the door!',
      required: true
    },
    {
      key: 'explore_features',
      title: 'Explore more features',
      description: 'Discover automation, analytics, and team features',
      required: false
    }
  ].freeze
  
  # Validations
  validates :current_step, inclusion: { in: ONBOARDING_STEPS.map { |s| s[:key] } }
  validates :completion_percentage, inclusion: { in: 0..100 }
  
  # Callbacks
  after_initialize :set_defaults
  after_update :update_completion_percentage
  
  # Scopes
  scope :completed, -> { where(completed: true) }
  scope :in_progress, -> { where(completed: false) }
  
  # Class methods
  def self.for_user(user)
    find_or_create_by(user: user)
  end
  
  def self.average_completion_time
    completed.average(:total_time_minutes) || 0
  end
  
  # Instance methods
  def current_step_info
    ONBOARDING_STEPS.find { |step| step[:key] == current_step }
  end
  
  def next_step
    current_index = ONBOARDING_STEPS.index { |step| step[:key] == current_step }
    return nil if current_index.nil? || current_index >= ONBOARDING_STEPS.length - 1
    
    ONBOARDING_STEPS[current_index + 1]
  end
  
  def previous_step
    current_index = ONBOARDING_STEPS.index { |step| step[:key] == current_step }
    return nil if current_index.nil? || current_index <= 0
    
    ONBOARDING_STEPS[current_index - 1]
  end
  
  def complete_step!(step_key, data = {})
    return false unless valid_step?(step_key)
    
    # Mark step as completed
    completed_steps[step_key] = {
      completed_at: Time.current.iso8601,
      data: data
    }
    
    # Move to next step if current
    if current_step == step_key
      move_to_next_step!
    end
    
    save!
  end
  
  def move_to_next_step!
    next_step_info = next_step
    if next_step_info
      self.current_step = next_step_info[:key]
    else
      complete_onboarding!
    end
  end
  
  def complete_onboarding!
    self.completed = true
    self.completed_at = Time.current
    self.total_time_minutes = calculate_total_time
    save!
    
    # Log completion for analytics
    AuditLog.log_user_action(
      user, 
      'onboarding_completed',
      user.account,
      { 
        time_taken_minutes: total_time_minutes,
        completion_rate: completion_percentage
      }
    )
  end
  
  def skip_to_step!(step_key)
    return false unless valid_step?(step_key)
    
    self.current_step = step_key
    save!
  end
  
  def restart!
    self.current_step = ONBOARDING_STEPS.first[:key]
    self.completed = false
    self.completed_at = nil
    self.completed_steps = {}
    save!
  end
  
  def step_completed?(step_key)
    completed_steps.key?(step_key.to_s)
  end
  
  def required_steps_completed?
    required_steps = ONBOARDING_STEPS.select { |s| s[:required] }
    required_steps.all? { |step| step_completed?(step[:key]) }
  end
  
  def progress_summary
    total_steps = ONBOARDING_STEPS.count
    completed_count = completed_steps.count
    
    {
      total_steps: total_steps,
      completed_steps: completed_count,
      current_step: current_step_info,
      next_step: next_step,
      completion_percentage: completion_percentage,
      completed: completed?,
      time_spent: time_spent_formatted
    }
  end
  
  # Indie-specific helpers
  def quick_start_completed?
    %w[business_info first_contacts choose_template].all? { |step| step_completed?(step) }
  end
  
  def ready_to_send?
    %w[first_contacts choose_template].all? { |step| step_completed?(step) }
  end
  
  def time_spent_formatted
    return "Not started" unless started_at
    return total_time_minutes.to_i.to_s + " minutes" if completed?
    
    minutes = ((Time.current - started_at) / 60).to_i
    "#{minutes} minutes"
  end
  
  private
  
  def set_defaults
    if new_record?
      self.current_step ||= ONBOARDING_STEPS.first[:key]
      self.completed_steps ||= {}
      self.started_at ||= Time.current
      self.completion_percentage ||= 0
    end
  end
  
  def update_completion_percentage
    total_steps = ONBOARDING_STEPS.count
    completed_count = completed_steps.count
    self.completion_percentage = (completed_count.to_f / total_steps * 100).round
  end
  
  def valid_step?(step_key)
    ONBOARDING_STEPS.any? { |step| step[:key] == step_key.to_s }
  end
  
  def calculate_total_time
    return 0 unless started_at
    ((completed_at || Time.current) - started_at) / 60
  end
end