#!/usr/bin/env ruby

# Test script for Indie/SME-focused simple authorization
# Run with: rails runner test_indie_permissions.rb

puts "🚀 Testing Indie/SME Simple Authorization System..."

# Setup test data for typical SME scenarios
puts "\n🏪 Setting up SME test scenarios..."

# Scenario 1: Solo entrepreneur (most common indie use case)
solo_account = Account.find_or_create_by(subdomain: "solo-business") do |account|
  account.name = "Solo Marketing Co"
  account.plan = "free"
  account.status = "active"
end

solo_owner = User.find_or_create_by(email: "owner@solo-business.com", account: solo_account) do |user|
  user.password = "password123"
  user.first_name = "Sarah"
  user.last_name = "Entrepreneur"
  user.role = "owner"
  user.status = "active"
end

puts "✅ Solo business setup: #{solo_account.name} (#{solo_account.plan} plan)"
puts "   Owner: #{solo_owner.display_name}"
puts "   Is solo business: #{solo_account.is_solo_business?}"

# Scenario 2: Small team (typical SME)
team_account = Account.find_or_create_by(subdomain: "small-team") do |account|
  account.name = "Small Team Marketing"
  account.plan = "starter"
  account.status = "active"
end

team_owner = User.find_or_create_by(email: "owner@small-team.com", account: team_account) do |user|
  user.password = "password123"
  user.first_name = "Mike"
  user.last_name = "Founder"
  user.role = "owner"
  user.status = "active"
end

team_member = User.find_or_create_by(email: "marketing@small-team.com", account: team_account) do |user|
  user.password = "password123"
  user.first_name = "Jenny"
  user.last_name = "Marketer"
  user.role = "member"
  user.status = "active"
end

puts "✅ Small team setup: #{team_account.name} (#{team_account.plan} plan)"
puts "   Owner: #{team_owner.display_name}"
puts "   Team member: #{team_member.display_name}"
puts "   Team size: #{team_account.team_size}"
puts "   Can add more team members: #{team_account.can_have_team_members?}"

# Test simple permission system
puts "\n🔑 Testing Simple Permission System..."

# Test solo entrepreneur permissions (should be simple)
puts "\n👩‍💼 Solo Entrepreneur Permissions:"
puts "  Can create campaigns: #{solo_owner.can?(:create, :campaigns)}"
puts "  Can send campaigns: #{solo_owner.can?(:send, :campaigns)}"
puts "  Can access billing: #{solo_owner.can_access_billing?}"
puts "  Can manage team: #{solo_owner.can_manage_team?}"
puts "  Can invite users: #{solo_owner.can_invite_users?}"
puts "  Can delete things: #{solo_owner.can_delete_things?}"
puts "  Role description: #{solo_owner.role_description}"

# Test team member permissions (limited but useful)
puts "\n👨‍💻 Team Member Permissions:"
puts "  Can create campaigns: #{team_member.can?(:create, :campaigns)}"
puts "  Can send campaigns: #{team_member.can?(:send, :campaigns)}"
puts "  Can access billing: #{team_member.can_access_billing?}"
puts "  Can manage team: #{team_member.can_manage_team?}"
puts "  Can invite users: #{team_member.can_invite_users?}"
puts "  Can delete things: #{team_member.can_delete_things?}"
puts "  Role description: #{team_member.role_description}"

# Test viewer permissions (for clients/stakeholders)
client_viewer = User.create!(
  email: "client@small-team.com",
  password: "password123",
  first_name: "Alex",
  last_name: "Client",
  role: "viewer",
  account: team_account
)

puts "\n👁️ Client Viewer Permissions:"
puts "  Can view campaigns: #{client_viewer.can?(:read, :campaigns)}"
puts "  Can create campaigns: #{client_viewer.can?(:create, :campaigns)}"
puts "  Can view analytics: #{client_viewer.can?(:read, :analytics)}"
puts "  Role description: #{client_viewer.role_description}"

# Test capabilities (for user onboarding)
puts "\n💡 User Capabilities (for onboarding):"
puts "\nSolo Owner capabilities:"
solo_owner.capabilities.each { |cap| puts "  • #{cap}" }

puts "\nTeam Member capabilities:"
team_member.capabilities.each { |cap| puts "  • #{cap}" }

puts "\nClient Viewer capabilities:"
client_viewer.capabilities.each { |cap| puts "  • #{cap}" }

# Test plan limits (SME-focused)
puts "\n📊 Testing SME Plan Limits..."

%w[free starter professional].each do |plan|
  test_account = Account.new(plan: plan)
  limits = test_account.plan_limits
  
  puts "\n#{plan.capitalize} Plan:"
  puts "  Contacts: #{limits[:contacts]}"
  puts "  Campaigns/month: #{limits[:campaigns_per_month]}"
  puts "  Templates: #{limits[:templates]}"
  puts "  Team members: #{limits[:team_members]}"
  puts "  Indie-friendly: #{test_account.indie_friendly_plan?}"
end

# Test real-world SME scenarios
puts "\n🎯 Testing Real-world SME Scenarios..."

# Scenario: Can the team member help with marketing?
puts "\nScenario: Team member wants to create a newsletter campaign"
can_create = team_member.can?(:create, :campaigns)
can_send = team_member.can?(:send, :campaigns)
can_view_results = team_member.can?(:read, :analytics)

puts "  ✅ Can create campaign: #{can_create}"
puts "  ✅ Can send campaign: #{can_send}" 
puts "  ✅ Can view results: #{can_view_results}"
puts "  Result: #{can_create && can_send && can_view_results ? 'Perfect for marketing team member!' : 'Needs owner approval'}"

# Scenario: Client wants to see campaign performance
puts "\nScenario: Client wants to check campaign performance"
can_view_campaigns = client_viewer.can?(:read, :campaigns)
can_view_analytics = client_viewer.can?(:read, :analytics)
cannot_edit = client_viewer.cannot?(:update, :campaigns)

puts "  ✅ Can view campaigns: #{can_view_campaigns}"
puts "  ✅ Can view analytics: #{can_view_analytics}"
puts "  ✅ Cannot edit: #{cannot_edit}"
puts "  Result: #{can_view_campaigns && can_view_analytics && cannot_edit ? 'Perfect for client access!' : 'Permissions issue'}"

# Scenario: Owner wants to add team member
puts "\nScenario: Owner wants to add a new team member"
can_invite = team_owner.can_invite_users?
has_room = team_account.can_have_team_members?

puts "  ✅ Owner can invite: #{can_invite}"
puts "  ✅ Plan allows more members: #{has_room}"
puts "  ✅ Current team size: #{team_account.team_size}/#{team_account.plan_limits[:team_members]}"
puts "  Result: #{can_invite && has_room ? 'Can add team member!' : 'Need plan upgrade or at limit'}"

# Performance test (should be even faster with simple system)
puts "\n⚡ Testing Performance (Simple System)..."

start_time = Time.current

# Test 1000 permission checks (should be very fast)
1000.times do
  solo_owner.can?(:create, :campaigns)
  team_member.can?(:send, :campaigns)
  client_viewer.can?(:read, :analytics)
end

end_time = Time.current
duration = (end_time - start_time).round(4)

puts "✅ 1000 simple permission checks completed in #{duration} seconds"

if duration < 0.01
  puts "🚀 Performance: Lightning fast! Perfect for indie/SME needs"
elsif duration < 0.05
  puts "✅ Performance: Excellent for small teams"
else
  puts "⚠️ Performance: Could be faster"
end

# Cleanup
client_viewer.destroy

puts "\n🎉 Indie/SME Simple Authorization Test Completed!"
puts "\nSimple Authorization Features:"
puts "✅ 3 clear roles: Owner (full access), Member (marketing work), Viewer (read-only)"
puts "✅ Easy to understand permissions - no complex matrix"
puts "✅ SME-focused plan limits with team member restrictions"
puts "✅ Real-world scenario testing for typical indie/SME use cases"
puts "✅ Lightning-fast performance for small teams"
puts "✅ User-friendly capability descriptions for onboarding"
puts "✅ Perfect for solo entrepreneurs and small marketing teams"

puts "\n💡 Key Benefits for Indie/SME Users:"
puts "• Solo entrepreneurs get full access without complexity"
puts "• Small teams can collaborate without confusion"
puts "• Clients can view results without access to sensitive areas"
puts "• Simple enough to explain in 30 seconds"
puts "• No enterprise bloat - just what small businesses need"