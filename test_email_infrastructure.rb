#!/usr/bin/env ruby

# Test script for email infrastructure
# Run with: rails runner test_email_infrastructure.rb

puts "🚀 Testing Email Infrastructure..."

# Create test account and user
account = Account.create!(
  name: "Test Marketing Co",
  subdomain: "test-marketing-#{SecureRandom.hex(4)}"
)

user = User.create!(
  email: "test-#{SecureRandom.hex(4)}@example.com",
  password: "password123",
  first_name: "Test",
  last_name: "User",
  role: "owner",
  account: account
)

# Create test contacts
contacts = []
5.times do |i|
  contacts << Contact.create!(
    email: "contact#{i}@example.com",
    first_name: "Contact",
    last_name: "#{i}",
    status: "subscribed",
    account: account
  )
end

# Create test campaign
campaign = Campaign.create!(
  name: "Test Email Campaign",
  subject: "Welcome {{first_name}}! Test from {{company_name}}",
  content: "<h1>Hello {{first_name}} {{last_name}}!</h1><p>This is a test email from {{company_name}}.</p><p>Today is {{date}}.</p>",
  status: "draft",
  from_email: "test@example.com",
  from_name: "Test Marketing",
  reply_to: "reply@example.com",
  send_type: "now",
  media_type: "text",
  account: account,
  user: user
)

puts "✅ Created test data:"
puts "   Account: #{account.name}"
puts "   User: #{user.email}"
puts "   Contacts: #{contacts.count}"
puts "   Campaign: #{campaign.name}"

# Test campaign validation
puts "\n🔍 Testing campaign validation..."
if campaign.can_be_sent?
  puts "✅ Campaign can be sent"
else
  puts "❌ Campaign cannot be sent"
  puts "   Status: #{campaign.status}"
  puts "   Errors: #{campaign.errors.full_messages}"
end

# Test job creation (without actually sending)
puts "\n🧪 Testing job creation..."
begin
  # Create job but don't execute it
  job = CampaignSenderJob.new(campaign.id)
  puts "✅ CampaignSenderJob created successfully"
  
  # Test contact filtering
  contacts_to_send = job.send(:get_campaign_contacts, campaign)
  puts "✅ Contact filtering: Found #{contacts_to_send.count} contacts to send to"
  
  # Test template rendering
  test_contact = contacts.first
  rendered_subject = job.send(:render_email_subject, campaign, test_contact)
  rendered_content = job.send(:render_email_content, campaign, test_contact)
  
  puts "✅ Template rendering:"
  puts "   Subject: #{rendered_subject}"
  puts "   Content preview: #{rendered_content[0..100]}..."
  
  # Test tracking token generation
  campaign_contact = CampaignContact.create!(
    campaign: campaign,
    contact: test_contact
  )
  
  tracking_params = job.send(:generate_tracking_params, campaign_contact)
  puts "✅ Tracking token generated: #{tracking_params[:open_token][0..20]}..."
  
rescue => e
  puts "❌ Error testing job: #{e.message}"
end

# Test scheduled campaign processor
puts "\n📅 Testing scheduled campaign processor..."
begin
  # Set campaign to scheduled in the past
  campaign.update!(
    status: "scheduled",
    scheduled_at: 1.minute.ago
  )
  
  ready_campaigns = Campaign.ready_to_send
  puts "✅ Found #{ready_campaigns.count} ready campaigns"
  
  processor_job = ScheduledCampaignProcessorJob.new
  puts "✅ ScheduledCampaignProcessorJob created successfully"
  
rescue => e
  puts "❌ Error testing scheduled processor: #{e.message}"
end

puts "\n🎉 Email infrastructure test completed!"
puts "\nNext steps:"
puts "1. Configure action_mailer for your environment"
puts "2. Set up background job processing (Solid Queue is configured)"
puts "3. Configure email tracking routes"
puts "4. Test with actual email delivery"

# Cleanup test data
puts "\n🧹 Cleaning up test data..."
account.destroy
puts "✅ Test data cleaned up"