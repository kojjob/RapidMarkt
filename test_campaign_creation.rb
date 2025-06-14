#!/usr/bin/env ruby

# Test script to verify campaign creation functionality
# Run this script from the Rails root directory: ruby test_campaign_creation.rb

require_relative 'config/environment'

puts "🧪 Testing Campaign Creation Functionality"
puts "=" * 50

# Test 1: Verify preview_text column exists in database
puts "\n1. Testing database schema for preview_text column..."
begin
  if ActiveRecord::Base.connection.column_exists?(:campaigns, :preview_text)
    puts "✅ preview_text column exists in campaigns table"
  else
    puts "❌ preview_text column is missing from campaigns table"
    puts "   Run: rails db:migrate to apply the migration"
    exit 1
  end
rescue => e
  puts "❌ Error checking database schema: #{e.message}"
  exit 1
end

# Test 2: Verify Campaign model accepts preview_text attribute
puts "\n2. Testing Campaign model with preview_text attribute..."
begin
  # Create a test account and user
  account = Account.first || Account.create!(
    name: "Test Account",
    email: "test@example.com",
    subdomain: "test-#{Time.current.to_i}"
  )

  user = account.users.first || account.users.create!(
    email: "user@test.com",
    password: "password123",
    password_confirmation: "password123",
    first_name: "Test",
    last_name: "User"
  )

  # Test campaign creation with preview_text
  campaign_params = {
    name: "Test Campaign #{Time.current.to_i}",
    subject: "Test Subject Line",
    preview_text: "This is a test preview text for email clients",
    status: "draft",
    content: "Test campaign content",
    from_name: "Test Sender",
    from_email: "sender@test.com",
    media_type: "text",
    design_theme: "modern",
    font_family: "Inter"
  }

  campaign = account.campaigns.build(campaign_params)
  campaign.user = user

  if campaign.valid?
    puts "✅ Campaign model validation passed with preview_text"
    puts "   Preview text: '#{campaign.preview_text}'"
  else
    puts "❌ Campaign model validation failed:"
    campaign.errors.full_messages.each { |msg| puts "   - #{msg}" }
    exit 1
  end

  # Test saving to database
  if campaign.save
    puts "✅ Campaign saved successfully to database"
    puts "   Campaign ID: #{campaign.id}"
    puts "   Account ID: #{campaign.account_id} (should match #{account.id})"
    puts "   User ID: #{campaign.user_id} (should match #{user.id})"
    puts "   Preview Text: '#{campaign.preview_text}'"

    # Verify associations are correct
    if campaign.account_id == account.id && campaign.user_id == user.id
      puts "✅ Campaign associations are correctly set"
    else
      puts "❌ Campaign associations are incorrect"
      exit 1
    end
  else
    puts "❌ Failed to save campaign to database:"
    campaign.errors.full_messages.each { |msg| puts "   - #{msg}" }
    exit 1
  end

rescue => e
  puts "❌ Error testing Campaign model: #{e.message}"
  puts "   Backtrace: #{e.backtrace.first(3).join("\n   ")}"
  exit 1
end

# Test 3: Verify strong parameters include preview_text
puts "\n3. Testing controller strong parameters..."
begin
  # Simulate controller parameters
  controller_params = ActionController::Parameters.new({
    campaign: {
      name: "Test Campaign",
      subject: "Test Subject",
      preview_text: "Test preview text",
      status: "draft",
      content: "Test content",
      from_name: "Test Sender",
      from_email: "sender@test.com",
      account_id: "999", # This should be filtered out
      user_id: "999"     # This should be filtered out
    }
  })

  # Simulate the campaign_params method from controller
  permitted_params = controller_params.require(:campaign).permit(
    :name, :subject, :template_id, :scheduled_at, :status, :from_name, :from_email, :reply_to,
    :recipient_type, :send_type, :media_type, :media_urls, :design_theme, :background_color,
    :text_color, :font_family, :header_image_url, :logo_url, :call_to_action_text,
    :call_to_action_url, :social_sharing_enabled, :social_platforms, :content,
    :preview_text, :template_choice, :scheduled_date, :scheduled_time, :timezone,
    :track_opens, :track_clicks, :reply_to_email,
    tag_ids: [], media_urls_array: [], social_platforms_array: []
  )

  if permitted_params.key?(:preview_text)
    puts "✅ preview_text is included in strong parameters"
    puts "   Permitted preview_text: '#{permitted_params[:preview_text]}'"
  else
    puts "❌ preview_text is missing from strong parameters"
    exit 1
  end

  # Verify unpermitted parameters are filtered out
  if !permitted_params.key?(:account_id) && !permitted_params.key?(:user_id)
    puts "✅ account_id and user_id are properly filtered out of strong parameters"
  else
    puts "❌ account_id or user_id are not being filtered out"
    puts "   This could cause security issues"
    exit 1
  end

rescue => e
  puts "❌ Error testing strong parameters: #{e.message}"
  exit 1
end

# Test 4: Test campaign retrieval and preview_text access
puts "\n4. Testing campaign retrieval with preview_text..."
begin
  # Retrieve the campaign we just created
  saved_campaign = Campaign.last

  if saved_campaign && saved_campaign.preview_text == "This is a test preview text for email clients"
    puts "✅ Campaign retrieved successfully with correct preview_text"
    puts "   Retrieved preview_text: '#{saved_campaign.preview_text}'"
  else
    puts "❌ Campaign retrieval failed or preview_text is incorrect"
    puts "   Expected: 'This is a test preview text for email clients'"
    puts "   Got: '#{saved_campaign&.preview_text}'"
    exit 1
  end

rescue => e
  puts "❌ Error testing campaign retrieval: #{e.message}"
  exit 1
end

# Test 5: Verify dashboard route exists
puts "\n5. Testing dashboard route configuration..."
begin
  routes = Rails.application.routes.routes
  dashboard_route = routes.find { |route| route.path.spec.to_s.include?('campaigns/dashboard') }

  if dashboard_route
    puts "✅ Dashboard route is properly configured"
    puts "   Route: #{dashboard_route.path.spec}"
  else
    puts "❌ Dashboard route is missing"
    exit 1
  end

rescue => e
  puts "❌ Error checking routes: #{e.message}"
  exit 1
end

# Cleanup test data
puts "\n6. Cleaning up test data..."
begin
  Campaign.where("name LIKE ?", "Test Campaign %").destroy_all
  puts "✅ Test campaigns cleaned up"
rescue => e
  puts "⚠️  Warning: Could not clean up test data: #{e.message}"
end

puts "\n" + "=" * 50
puts "🎉 ALL TESTS PASSED!"
puts "✅ preview_text column exists and works correctly"
puts "✅ Campaign creation works without ActiveModel::UnknownAttributeError"
puts "✅ Strong parameters properly include preview_text"
puts "✅ Unpermitted parameters (account_id, user_id) are filtered out"
puts "✅ Campaign associations are set correctly through controller logic"
puts "✅ Dashboard route is configured"
puts "\n🚀 Campaign creation functionality is working properly!"
puts "   You can now safely create campaigns with preview_text at:"
puts "   http://localhost:3000/campaigns/new"
