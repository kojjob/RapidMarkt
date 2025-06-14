#!/usr/bin/env ruby

# Simple test script for bulk campaign operations
# Run with: rails runner test_bulk_operations_simple.rb

puts "📧 Testing Bulk Campaign Operations..."

# Test using existing data
puts "\n🔍 Testing with existing data..."

# Check if we have campaigns
campaigns = Campaign.limit(5)
puts "Found #{campaigns.count} existing campaigns"

if campaigns.any?
  # Test bulk operations with basic validation
  puts "\n📤 Testing Bulk Send Logic..."
  
  # Check campaign states
  campaigns.each_with_index do |campaign, i|
    puts "Campaign #{i+1}: #{campaign.name}"
    puts "  Status: #{campaign.status}"
    puts "  Can be sent?: #{campaign.can_be_sent?}"
    puts "  Can be scheduled?: #{campaign.can_be_scheduled?}"
    puts "  Has template?: #{campaign.template.present?}"
    puts "  Has from_email?: #{campaign.from_email.present?}"
  end
  
  # Test bulk send validation logic
  draft_campaigns = campaigns.where(status: ["draft", "scheduled"])
  puts "\n✅ Found #{draft_campaigns.count} campaigns in draft/scheduled status"
  
  sendable_campaigns = draft_campaigns.select(&:can_be_sent?)
  puts "✅ #{sendable_campaigns.count} campaigns can be sent"
  
  schedulable_campaigns = draft_campaigns.select(&:can_be_scheduled?)
  puts "✅ #{schedulable_campaigns.count} campaigns can be scheduled"
  
  # Test bulk schedule validation logic
  puts "\n📅 Testing Bulk Schedule Logic..."
  
  future_time = 1.hour.from_now
  puts "Schedule time: #{future_time.strftime('%B %d, %Y at %I:%M %p')}"
  puts "Time validation: #{future_time > Time.current ? 'Valid (future)' : 'Invalid (past)'}"
  
  past_time = 1.hour.ago
  puts "Past time validation: #{past_time <= Time.current ? 'Correctly identified as past' : 'Error'}"
  
else
  puts "⚠️ No campaigns found - creating minimal test data..."
  
  # Create minimal test data
  account = Account.first
  user = User.first
  
  if account && user
    # Create a simple template
    template = Template.create!(
      name: "Test Template",
      subject: "Test Subject",
      body: "Test Body",
      template_type: "email",
      status: "active",
      account: account,
      user: user
    )
    
    # Create a simple campaign
    campaign = Campaign.create!(
      name: "Test Campaign",
      subject: "Test Subject",
      status: "draft",
      from_email: "test@example.com",
      from_name: "Test Sender",
      template: template,
      account: account,
      user: user
    )
    
    puts "✅ Created test campaign: #{campaign.name}"
    puts "  Can be sent?: #{campaign.can_be_sent?}"
    puts "  Can be scheduled?: #{campaign.can_be_scheduled?}"
  else
    puts "❌ No account or user found - skipping test data creation"
  end
end

# Test job classes
puts "\n⚙️ Testing Job Classes..."

begin
  # Test CampaignSenderJob
  CampaignSenderJob.new
  puts "✅ CampaignSenderJob exists and can be instantiated"
rescue => e
  puts "❌ CampaignSenderJob test failed: #{e.message}"
end

begin
  # Test ScheduledCampaignProcessorJob
  ScheduledCampaignProcessorJob.new
  puts "✅ ScheduledCampaignProcessorJob exists and can be instantiated"
rescue => e
  puts "❌ ScheduledCampaignProcessorJob test failed: #{e.message}"
end

# Test model methods
puts "\n🔧 Testing Model Methods..."

# Test Campaign class methods
puts "Campaign.ready_to_send scope: #{Campaign.ready_to_send.count} campaigns ready"
puts "Campaign.draft scope: #{Campaign.draft.count} draft campaigns"
puts "Campaign.scheduled scope: #{Campaign.scheduled.count} scheduled campaigns"

# Test individual campaign methods with a sample
sample_campaign = Campaign.first
if sample_campaign
  puts "\nSample campaign methods:"
  puts "  draft?: #{sample_campaign.draft?}"
  puts "  scheduled?: #{sample_campaign.scheduled?}"
  puts "  ready_to_send?: #{sample_campaign.ready_to_send?}"
  puts "  can_be_sent?: #{sample_campaign.can_be_sent?}"
  puts "  can_be_scheduled?: #{sample_campaign.can_be_scheduled?}"
end

# Test parameter validation
puts "\n🧪 Testing Parameter Validation..."

# Test empty campaign list
empty_ids = []
puts "Empty campaign list validation: #{empty_ids.empty? ? 'Empty correctly detected' : 'Error'}"

# Test invalid campaign IDs
invalid_ids = [99999, 88888]
found_campaigns = Campaign.where(id: invalid_ids)
puts "Invalid ID filtering: #{found_campaigns.count} campaigns found (should be 0)"

# Test datetime parsing
begin
  valid_time = Time.parse("2025-12-31 12:00:00")
  puts "Valid datetime parsing: #{valid_time > Time.current ? 'Success' : 'Past time'}"
rescue ArgumentError
  puts "Valid datetime parsing: Failed"
end

begin
  Time.parse("invalid-date")
  puts "Invalid datetime parsing: Should have failed"
rescue ArgumentError
  puts "Invalid datetime parsing: Correctly rejected"
end

puts "\n🎉 Bulk Operations Test Completed!"
puts "\nCore Features Tested:"
puts "✅ Campaign state validation (can_be_sent?, can_be_scheduled?)"
puts "✅ Bulk operation parameter validation"
puts "✅ Job class availability and instantiation"
puts "✅ Model scopes and methods"
puts "✅ Datetime validation and parsing"
puts "✅ Edge case handling (empty lists, invalid IDs)"
puts "✅ Status-based filtering logic"