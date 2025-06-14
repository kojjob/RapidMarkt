# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Clear existing data in development
if Rails.env.development?
  puts "Clearing existing data..."
  CampaignContact.destroy_all
  Campaign.destroy_all
  Contact.destroy_all
  Template.destroy_all
  User.destroy_all
  Account.destroy_all
end

puts "Creating seed data..."

# Create accounts
account1 = Account.create!(
  name: "Acme Marketing Co",
  subdomain: "acme",
  plan: "starter",
  status: "active"
)

account2 = Account.create!(
  name: "StartupXYZ",
  subdomain: "startupxyz",
  plan: "professional",
  status: "active"
)

puts "Created #{Account.count} accounts"

# Create users
user1 = User.create!(
  email: "admin@acme.com",
  password: "password123",
  password_confirmation: "password123",
  first_name: "John",
  last_name: "Smith",
  role: "admin",
  account: account1
)

user2 = User.create!(
  email: "sarah@acme.com",
  password: "password123",
  password_confirmation: "password123",
  first_name: "Sarah",
  last_name: "Johnson",
  role: "member",
  account: account1
)

user3 = User.create!(
  email: "founder@startupxyz.com",
  password: "password123",
  password_confirmation: "password123",
  first_name: "Mike",
  last_name: "Chen",
  role: "admin",
  account: account2
)

puts "Created #{User.count} users"

# Create sample templates
template1 = Template.create!(
  account: account1,
  name: "Welcome Email",
  subject: "Welcome to {{company_name}}!",
  body: "<h1>Welcome {{first_name}}!</h1><p>Thank you for joining {{company_name}}. We're excited to have you on board!</p>",
  template_type: "email",
  status: "active"
)

template2 = Template.create!(
  account: account1,
  name: "Newsletter Template",
  subject: "{{company_name}} Monthly Newsletter",
  body: "<h1>Monthly Update</h1><p>Hi {{first_name}},</p><p>Here's what's new at {{company_name}} this month...</p>",
  template_type: "newsletter",
  status: "active"
)

template3 = Template.create!(
  account: account2,
  name: "Product Launch",
  subject: "Exciting News: New Product Launch!",
  body: "<h1>Big News, {{first_name}}!</h1><p>We're thrilled to announce our latest product. Check it out!</p>",
  template_type: "promotional",
  status: "active"
)

puts "Created #{Template.count} templates"

# Create contacts for account1
contacts_data = [
  { first_name: "Alice", last_name: "Williams", email: "alice@example.com", status: "subscribed", tags: ["customer", "vip"] },
  { first_name: "Bob", last_name: "Davis", email: "bob@example.com", status: "subscribed", tags: ["prospect"] },
  { first_name: "Carol", last_name: "Miller", email: "carol@example.com", status: "subscribed", tags: ["customer"] },
  { first_name: "David", last_name: "Wilson", email: "david@example.com", status: "unsubscribed", tags: ["former_customer"] },
  { first_name: "Emma", last_name: "Brown", email: "emma@example.com", status: "subscribed", tags: ["prospect", "newsletter"] },
  { first_name: "Frank", last_name: "Taylor", email: "frank@example.com", status: "subscribed", tags: ["customer"] },
  { first_name: "Grace", last_name: "Anderson", email: "grace@example.com", status: "subscribed", tags: ["vip", "customer"] },
  { first_name: "Henry", last_name: "Thomas", email: "henry@example.com", status: "subscribed", tags: ["prospect"] },
  { first_name: "Ivy", last_name: "Jackson", email: "ivy@example.com", status: "subscribed", tags: ["newsletter"] },
  { first_name: "Jack", last_name: "White", email: "jack@example.com", status: "subscribed", tags: ["customer", "newsletter"] }
]

contacts_data.each do |contact_data|
  contact = Contact.create!(
    account: account1,
    first_name: contact_data[:first_name],
    last_name: contact_data[:last_name],
    email: contact_data[:email],
    status: contact_data[:status]
  )
  
  # Add tags using the proper association
  contact_data[:tags].each do |tag_name|
    contact.add_tag(tag_name)
  end
end

# Create some contacts for account2
3.times do |i|
  contact = Contact.create!(
    account: account2,
    first_name: "User#{i + 1}",
    last_name: "Test",
    email: "user#{i + 1}@test.com",
    status: "subscribed"
  )
  
  # Add tags using the proper association
  contact.add_tag("beta_user")
end

puts "Created #{Contact.count} contacts"

# Create campaigns for account1
campaign1 = Campaign.create!(
  account: account1,
  template: template1,
  name: "Welcome Series - Week 1",
  subject: "Welcome to Acme Marketing Co!",
  status: "sent",
  open_rate: 75.0,
  click_rate: 37.5,
  sent_at: 5.days.ago,
  created_at: 6.days.ago
)

campaign2 = Campaign.create!(
  account: account1,
  template: template2,
  name: "Monthly Newsletter - December",
  subject: "Acme Marketing Co Monthly Newsletter - December 2024",
  status: "sent",
  open_rate: 62.5,
  click_rate: 25.0,
  sent_at: 3.days.ago,
  created_at: 4.days.ago
)

campaign3 = Campaign.create!(
  account: account1,
  name: "Holiday Special Offer",
  subject: "🎄 Special Holiday Discount - Limited Time!",
  status: "draft",
  created_at: 1.day.ago
)

campaign4 = Campaign.create!(
  account: account2,
  template: template3,
  name: "Product Launch Campaign",
  subject: "Exciting News: New Product Launch!",
  status: "scheduled",
  scheduled_at: 2.days.from_now,
  created_at: 2.days.ago
)

puts "Created #{Campaign.count} campaigns"

# Create campaign contacts for sent campaigns
sent_campaigns = [campaign1, campaign2]
subscribed_contacts = account1.contacts.where(status: "subscribed")

sent_campaigns.each do |campaign|
  # Send to all subscribed contacts for this account
  contacts_to_send = subscribed_contacts.to_a
  sent_count = contacts_to_send.size
  opened_count = (sent_count * (campaign.open_rate || 0) / 100).round
  clicked_count = (opened_count * (campaign.click_rate || 0) / 100).round
  
  contacts_to_send.each_with_index do |contact, index|
    opened = index < opened_count
    clicked = opened && index < clicked_count
    
    CampaignContact.create!(
      campaign: campaign,
      contact: contact,
      sent_at: campaign.sent_at,
      opened_at: opened ? campaign.sent_at + rand(1..48).hours : nil,
      clicked_at: clicked ? campaign.sent_at + rand(2..72).hours : nil
    )
  end
end

# Create campaign contacts for account2
account2_contacts = account2.contacts.where(status: "subscribed")
campaign4_contacts = account2_contacts.to_a
sent_count = campaign4_contacts.size
opened_count = (sent_count * (campaign4.open_rate || 0) / 100).round
clicked_count = (opened_count * (campaign4.click_rate || 0) / 100).round

campaign4_contacts.each_with_index do |contact, index|
  opened = index < opened_count
  clicked = opened && index < clicked_count
  
  CampaignContact.create!(
    campaign: campaign4,
    contact: contact,
    sent_at: campaign4.scheduled_at,
    opened_at: opened ? campaign4.scheduled_at + rand(1..48).hours : nil,
    clicked_at: clicked ? campaign4.scheduled_at + rand(2..72).hours : nil
  )
end

puts "Created #{CampaignContact.count} campaign contacts"

puts "\n✅ Seed data created successfully!"
puts "\n📊 Summary:"
puts "   • #{Account.count} accounts"
puts "   • #{User.count} users"
puts "   • #{Template.count} templates"
puts "   • #{Contact.count} contacts"
puts "   • #{Campaign.count} campaigns"
puts "   • #{CampaignContact.count} campaign contacts"
puts "\n🔑 Login credentials:"
puts "   • admin@acme.com / password123 (Admin)"
puts "   • sarah@acme.com / password123 (Member)"
puts "   • founder@startupxyz.com / password123 (Admin)"
