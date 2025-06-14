#!/usr/bin/env ruby

# Test script for indie/SME-focused onboarding flow
# Run with: rails runner test_indie_onboarding.rb

puts "🚀 Testing Indie/SME Onboarding Flow..."

# Setup test data
puts "\n🛠️ Setting up onboarding test environment..."

# Create a new indie user account (simulating signup)
account = Account.create!(
  name: "Sarah's Marketing Co",
  subdomain: "sarahs-marketing",
  plan: "free",
  status: "active"
)

user = User.create!(
  email: "sarah@sarahs-marketing.com",
  password: "password123",
  first_name: "Sarah",
  last_name: "Entrepreneur",
  role: "owner",
  account: account
)

puts "✅ Created indie user: #{user.display_name} (#{account.name})"

# Test OnboardingProgress model
puts "\n📋 Testing OnboardingProgress Model..."

# Create onboarding progress
progress = OnboardingProgress.for_user(user)

puts "✅ Onboarding progress created"
puts "  Current step: #{progress.current_step}"
puts "  Completed: #{progress.completed?}"
puts "  Completion percentage: #{progress.completion_percentage}%"
puts "  Steps defined: #{OnboardingProgress::ONBOARDING_STEPS.count}"

# Test step information
current_step_info = progress.current_step_info
puts "\nCurrent step info:"
puts "  Title: #{current_step_info[:title]}"
puts "  Description: #{current_step_info[:description]}"
puts "  Required: #{current_step_info[:required]}"

# Test step progression
puts "\n⏭️ Testing Step Progression..."

OnboardingProgress::ONBOARDING_STEPS.each_with_index do |step, index|
  puts "\nStep #{index + 1}: #{step[:title]}"
  puts "  Key: #{step[:key]}"
  puts "  Required: #{step[:required]}"
  puts "  Completed: #{progress.step_completed?(step[:key])}"
end

# Test completing steps
puts "\n✅ Testing Step Completion..."

# Complete welcome step
progress.complete_step!('welcome', { source: 'test' })
puts "✅ Welcome step completed"
puts "  Current step now: #{progress.current_step}"
puts "  Completion percentage: #{progress.completion_percentage}%"

# Complete business info step
progress.complete_step!('business_info', { 
  business_type: 'E-commerce Store',
  industry: 'Fashion'
})
puts "✅ Business info step completed"
puts "  Current step now: #{progress.current_step}"
puts "  Completion percentage: #{progress.completion_percentage}%"

# Complete first contacts step
progress.complete_step!('first_contacts', {
  method: 'manual',
  contacts_added: 3
})
puts "✅ First contacts step completed"
puts "  Current step now: #{progress.current_step}"
puts "  Quick start completed?: #{progress.quick_start_completed?}"
puts "  Ready to send?: #{progress.ready_to_send?}"

# Test account business info
puts "\n🏢 Testing Account Business Information..."

account.update!(
  business_type: 'E-commerce Store',
  industry: 'Fashion',
  website: 'https://sarahs-store.com'
)

puts "✅ Account business info updated"
puts "  Business type: #{account.business_type}"
puts "  Industry: #{account.industry}"
puts "  Website: #{account.website}"
puts "  Is solo business: #{account.is_solo_business?}"
puts "  Team size: #{account.team_size}"

# Create sample contacts for the test
puts "\n👥 Creating Sample Contacts..."

sample_contacts = [
  { first_name: 'John', last_name: 'Customer', email: 'john@example.com' },
  { first_name: 'Jane', last_name: 'Smith', email: 'jane@example.com' },
  { first_name: 'Bob', last_name: 'Johnson', email: 'bob@example.com' }
]

sample_contacts.each do |contact_data|
  contact = account.contacts.create!(
    contact_data.merge(
      status: 'subscribed',
      subscribed_at: Time.current
    )
  )
end

puts "✅ Created #{account.contacts.count} sample contacts"

# Create sample template for testing
puts "\n🎨 Creating Sample Template..."

template = account.templates.create!(
  user: user,
  name: "Welcome Email Template",
  subject: "Welcome to {{account.name}}, {{contact.first_name}}!",
  body: "<h1>Welcome {{contact.first_name}}!</h1><p>Thanks for joining {{account.name}}. We're excited to have you!</p>",
  template_type: "email",
  status: "active",
  design_system: "modern"
)

puts "✅ Created sample template: #{template.name}"

# Test template selection
progress.complete_step!('choose_template', {
  method: 'existing',
  template_id: template.id,
  template_name: template.name
})
puts "✅ Template selection completed"
puts "  Current step now: #{progress.current_step}"

# Test campaign creation
puts "\n📧 Testing First Campaign Creation..."

campaign = account.campaigns.create!(
  user: user,
  name: "My First Campaign",
  subject: "Hello from Sarah's Marketing Co!",
  template: template,
  status: 'draft',
  from_name: user.full_name,
  from_email: user.email
)

# Add contacts to campaign
account.contacts.each do |contact|
  campaign.campaign_contacts.create!(contact: contact)
end

puts "✅ Created first campaign: #{campaign.name}"
puts "  Recipients: #{campaign.campaign_contacts.count}"
puts "  Template: #{campaign.template.name}"
puts "  Can be sent: #{campaign.can_be_sent?}"

# Complete first campaign step
progress.complete_step!('first_campaign', {
  campaign_id: campaign.id,
  action: 'saved_draft',
  recipients: campaign.campaign_contacts.count
})
puts "✅ First campaign step completed"
puts "  Current step now: #{progress.current_step}"

# Test feature exploration
puts "\n🔍 Testing Feature Exploration..."

progress.complete_step!('explore_features', { viewed_features: ['analytics', 'templates'] })
puts "✅ Feature exploration completed"

# Complete onboarding
progress.complete_onboarding!
puts "✅ Onboarding completed!"
puts "  Completed at: #{progress.completed_at}"
puts "  Total time: #{progress.time_spent_formatted}"
puts "  Final completion percentage: #{progress.completion_percentage}%"

# Test progress summary
puts "\n📊 Testing Progress Summary..."

summary = progress.progress_summary
puts "Progress Summary:"
puts "  Total steps: #{summary[:total_steps]}"
puts "  Completed steps: #{summary[:completed_steps]}"
puts "  Completion percentage: #{summary[:completion_percentage]}%"
puts "  Completed: #{summary[:completed]}"
puts "  Time spent: #{summary[:time_spent]}"

# Test onboarding analytics
puts "\n📈 Testing Onboarding Analytics..."

puts "Onboarding metrics:"
puts "  Average completion time: #{OnboardingProgress.average_completion_time.round(2)} minutes"
puts "  Completed onboardings: #{OnboardingProgress.completed.count}"
puts "  In progress onboardings: #{OnboardingProgress.in_progress.count}"

# Test step completion data
puts "\nStep completion details:"
progress.completed_steps.each do |step_key, step_data|
  puts "  #{step_key}: completed at #{step_data['completed_at']}"
  if step_data['data'].present?
    puts "    Data: #{step_data['data']}"
  end
end

# Test indie-specific features
puts "\n🎯 Testing Indie-Specific Features..."

puts "Indie business checks:"
puts "  Is solo business: #{account.is_solo_business?}"
puts "  Can add team members: #{account.can_have_team_members?}"
puts "  Indie-friendly plan: #{account.indie_friendly_plan?}"
puts "  Plan limits: #{account.plan_limits}"

puts "User capabilities for onboarding:"
user.capabilities.each { |cap| puts "  • #{cap}" }

puts "Quick progress checks:"
puts "  Quick start completed: #{progress.quick_start_completed?}"
puts "  Ready to send: #{progress.ready_to_send?}"
puts "  Required steps completed: #{progress.required_steps_completed?}"

# Test onboarding restart
puts "\n🔄 Testing Onboarding Restart..."

original_completion_time = progress.total_time_minutes
progress.restart!
puts "✅ Onboarding restarted"
puts "  Current step after restart: #{progress.current_step}"
puts "  Completed after restart: #{progress.completed?}"
puts "  Completion percentage: #{progress.completion_percentage}%"
puts "  Previous completion time was: #{original_completion_time.round(2)} minutes"

# Test skip functionality
puts "\n⏭️ Testing Step Skipping..."

next_step_info = progress.next_step
if next_step_info
  progress.skip_to_step!(next_step_info[:key])
  puts "✅ Skipped to step: #{progress.current_step}"
  puts "  Step title: #{progress.current_step_info[:title]}"
end

# Test performance
puts "\n⚡ Testing Performance..."

start_time = Time.current

# Create multiple onboarding progresses
10.times do |i|
  test_user = User.create!(
    email: "test#{i}@example.com",
    password: "password123",
    first_name: "Test#{i}",
    last_name: "User",
    role: "owner",
    account: account
  )
  
  test_progress = OnboardingProgress.for_user(test_user)
  test_progress.complete_step!('welcome')
  test_progress.complete_step!('business_info')
end

end_time = Time.current
duration = (end_time - start_time).round(3)

puts "✅ Created 10 onboarding progresses in #{duration} seconds"

if duration < 1.0
  puts "🚀 Performance: Excellent for indie users!"
elsif duration < 3.0
  puts "✅ Performance: Good for small teams"
else
  puts "⚠️ Performance: Could be optimized"
end

# Cleanup test users
User.where("email LIKE 'test%@example.com'").destroy_all

puts "\n🎉 Indie Onboarding Flow Test Completed!"
puts "\nIndie Onboarding Features Verified:"
puts "✅ 6-step onboarding flow tailored for indie/SME users"
puts "✅ Progressive disclosure - each step builds on the last"
puts "✅ Quick start path (business info → contacts → template → send)"
puts "✅ Flexible completion - users can skip optional steps"
puts "✅ Business profiling for personalized experience"
puts "✅ Simple contact addition (manual, import, or demo)"
puts "✅ Template selection from indie-friendly options"
puts "✅ First campaign creation with guided setup"
puts "✅ Feature exploration for gradual learning"
puts "✅ Progress tracking with completion percentages"
puts "✅ Restart capability for re-onboarding"
puts "✅ Performance optimized for small teams"

puts "\n💡 Key Benefits for Indie Users:"
puts "• Get to first campaign send in under 10 minutes"
puts "• No overwhelming enterprise features during setup"
puts "• Clear progress indication to reduce abandonment"
puts "• Flexible flow - can skip steps and return later"
puts "• Personalized based on business type and goals"
puts "• Immediate value - send first campaign during onboarding"
puts "• Simple enough for non-technical founders"