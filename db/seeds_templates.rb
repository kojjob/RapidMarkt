#!/usr/bin/env ruby

puts "🎨 Seeding Enhanced Template System..."

# Find or create a demo account for public templates
demo_account = Account.find_or_create_by(name: "RapidMarkt", subdomain: "rapidmarkt-demo") do |account|
  account.plan = "enterprise"
  account.status = "active"
end

demo_user = User.find_or_create_by(email: "system@rapidmarkt.com") do |user|
  user.password = "password123"
  user.first_name = "System"
  user.last_name = "Admin"
  user.role = "owner"
  user.account = demo_account
end

# Template data
templates_data = [
  {
    name: "Welcome Newsletter",
    subject: "Welcome to {{account.name}}, {{contact.first_name}}!",
    description: "A warm welcome email for new subscribers with modern design and clear call-to-action.",
    body: %{
      <h1>Welcome {{contact.first_name}}!</h1>
      <p>Thank you for joining {{account.name}}. We're excited to have you on board!</p>
      <p>You'll receive updates about our latest features, tips, and exclusive content.</p>
      <div style="text-align: center; margin: 30px 0;">
        <a href="#" style="background: #2563eb; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; font-weight: 600;">Get Started</a>
      </div>
      <p>Best regards,<br>The {{account.name}} Team</p>
    },
    template_type: "email",
    design_system: "modern",
    color_scheme: { primary: "#2563eb", secondary: "#64748b", accent: "#10b981" },
    tags: ["welcome", "onboarding", "newsletter"],
    is_public: true,
    is_premium: false,
    rating: 4.8
  },
  {
    name: "Product Launch Announcement",
    subject: "🚀 Big News: {{campaign.name}} is Here!",
    description: "Perfect for announcing new products or features with excitement and clear benefits.",
    body: %{
      <h1>🚀 We've got big news!</h1>
      <p>Hi {{contact.first_name}},</p>
      <p>We're thrilled to announce our latest product that we know you'll love.</p>
      
      <div style="background: #f8fafc; padding: 20px; border-radius: 8px; margin: 20px 0;">
        <h2 style="margin-top: 0; color: #1f2937;">Key Features:</h2>
        <ul style="line-height: 1.8;">
          <li>Feature 1: Amazing capability</li>
          <li>Feature 2: Incredible functionality</li>
          <li>Feature 3: Game-changing innovation</li>
        </ul>
      </div>
      
      <div style="text-align: center; margin: 30px 0;">
        <a href="#" style="background: #10b981; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 16px;">Learn More</a>
      </div>
      
      <p>Questions? Just reply to this email - we'd love to hear from you!</p>
    },
    template_type: "promotional",
    design_system: "modern",
    color_scheme: { primary: "#10b981", secondary: "#64748b", accent: "#f59e0b" },
    tags: ["product", "launch", "announcement", "promotion"],
    is_public: true,
    is_premium: false,
    rating: 4.6
  },
  {
    name: "Monthly Newsletter Classic",
    subject: "{{account.name}} Monthly Update - {{current_date}}",
    description: "A classic, professional newsletter template perfect for regular updates and communications.",
    body: %{
      <h1 style="color: #1f2937; border-bottom: 2px solid #e5e7eb; padding-bottom: 10px;">Monthly Update</h1>
      
      <p>Dear {{contact.first_name}},</p>
      
      <p>Here's what's been happening at {{account.name}} this month:</p>
      
      <h2 style="color: #374151; margin-top: 30px;">📈 This Month's Highlights</h2>
      <ul style="line-height: 1.8;">
        <li>Achievement 1: Brief description</li>
        <li>Achievement 2: Brief description</li>
        <li>Achievement 3: Brief description</li>
      </ul>
      
      <h2 style="color: #374151; margin-top: 30px;">📚 Featured Content</h2>
      <p>Don't miss our latest blog post about industry trends and insights.</p>
      
      <h2 style="color: #374151; margin-top: 30px;">📅 Upcoming Events</h2>
      <p>Mark your calendar for our upcoming webinar on {{current_date}}.</p>
      
      <p style="margin-top: 30px;">Thank you for being part of our community!</p>
      
      <p>Best regards,<br>{{account.name}} Team</p>
    },
    template_type: "newsletter",
    design_system: "classic",
    color_scheme: { primary: "#1f2937", secondary: "#6b7280", accent: "#3b82f6" },
    tags: ["newsletter", "monthly", "update", "classic"],
    is_public: true,
    is_premium: false,
    rating: 4.4
  },
  {
    name: "Event Invitation Premium",
    subject: "You're Invited: Exclusive Event on {{current_date}}",
    description: "Elegant invitation template for exclusive events, webinars, or special occasions.",
    body: %{
      <div style="text-align: center; margin-bottom: 30px;">
        <h1 style="font-size: 32px; margin: 0; color: #1f2937;">You're Invited</h1>
        <p style="font-size: 18px; color: #6b7280; margin: 10px 0;">to an exclusive event</p>
      </div>
      
      <p>Dear {{contact.first_name}},</p>
      
      <p>We're delighted to invite you to our exclusive event designed specifically for valued members like yourself.</p>
      
      <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 12px; text-align: center; margin: 30px 0;">
        <h2 style="margin: 0 0 10px 0; font-size: 24px;">Special Event Title</h2>
        <p style="margin: 0; opacity: 0.9; font-size: 16px;">{{current_date}} at {{current_time}}</p>
      </div>
      
      <h3 style="color: #1f2937;">What to Expect:</h3>
      <ul style="line-height: 1.8;">
        <li>Exclusive insights from industry leaders</li>
        <li>Networking opportunities</li>
        <li>Live Q&A session</li>
        <li>Special announcements</li>
      </ul>
      
      <div style="text-align: center; margin: 40px 0;">
        <a href="#" style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 16px 32px; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; box-shadow: 0 4px 12px rgba(102, 126, 234, 0.3);">Reserve Your Spot</a>
      </div>
      
      <p><em>Limited seats available. RSVP by {{current_date}}.</em></p>
    },
    template_type: "email",
    design_system: "modern",
    color_scheme: { primary: "#667eea", secondary: "#764ba2", accent: "#f093fb" },
    tags: ["event", "invitation", "exclusive", "premium"],
    is_public: true,
    is_premium: true,
    rating: 4.9
  },
  {
    name: "Minimal Thank You",
    subject: "Thank you, {{contact.first_name}}",
    description: "Clean, minimal design perfect for thank you messages and simple communications.",
    body: %{
      <div style="text-align: center; margin: 40px 0;">
        <h1 style="font-size: 28px; font-weight: 300; color: #1f2937; margin: 0;">Thank You</h1>
      </div>
      
      <p style="font-size: 16px; line-height: 1.6;">Hi {{contact.first_name}},</p>
      
      <p style="font-size: 16px; line-height: 1.6;">We wanted to take a moment to thank you for choosing {{account.name}}.</p>
      
      <p style="font-size: 16px; line-height: 1.6;">Your support means everything to us, and we're committed to providing you with the best possible experience.</p>
      
      <div style="margin: 40px 0; padding: 20px; background: #f9fafb; border-left: 4px solid #e5e7eb;">
        <p style="margin: 0; font-style: italic; color: #6b7280;">"Thank you for being an amazing customer!"</p>
      </div>
      
      <p style="font-size: 16px; line-height: 1.6;">If you have any questions or feedback, we'd love to hear from you.</p>
      
      <p style="font-size: 16px; line-height: 1.6; margin-top: 30px;">
        With gratitude,<br>
        The {{account.name}} Team
      </p>
    },
    template_type: "transactional",
    design_system: "minimal",
    color_scheme: { primary: "#1f2937", secondary: "#6b7280", accent: "#e5e7eb" },
    tags: ["thank you", "minimal", "gratitude", "simple"],
    is_public: true,
    is_premium: false,
    rating: 4.7
  }
]

# Create templates
templates_data.each do |template_data|
  template = Template.find_or_create_by(
    name: template_data[:name],
    account: demo_account
  ) do |t|
    t.user = demo_user
    t.subject = template_data[:subject]
    t.description = template_data[:description]
    t.body = template_data[:body]
    t.template_type = template_data[:template_type]
    t.design_system = template_data[:design_system]
    t.color_scheme = template_data[:color_scheme]
    t.tags = template_data[:tags]
    t.is_public = template_data[:is_public]
    t.is_premium = template_data[:is_premium]
    t.rating = template_data[:rating]
    t.usage_count = rand(50..500) # Simulate usage
    t.status = "active"
  end
  
  puts "✅ Created template: #{template.name}"
end

puts "🎉 Enhanced template system seeded successfully!"
puts "Created #{templates_data.length} professional templates"
puts "Templates include: welcome emails, newsletters, product launches, events, and thank you messages"
puts "Design systems: modern, classic, and minimal"
puts "Features: variable substitution, color schemes, tags, ratings, and public/premium templates"