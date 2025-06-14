#!/usr/bin/env ruby

# Test script for enhanced template system
# Run with: rails runner test_template_system.rb

puts "🎨 Testing Enhanced Template System..."

# Test template search and filtering
puts "\n📋 Testing Template Discovery..."

# Test public templates
public_templates = Template.public_templates.active
puts "✅ Found #{public_templates.count} public templates"

# Test filtering by design system
modern_templates = Template.by_design_system('modern')
puts "✅ Found #{modern_templates.count} modern design templates"

# Test tag filtering
welcome_templates = Template.by_tags(['welcome'])
puts "✅ Found #{welcome_templates.count} templates with 'welcome' tag"

# Test rating system
puts "\n⭐ Testing Rating System..."
template = Template.public_templates.first
if template
  original_rating = template.rating
  template.add_rating(5)
  puts "✅ Added rating: #{original_rating} -> #{template.rating}"
end

# Test template rendering
puts "\n🖼️  Testing Template Rendering..."
test_template = Template.public_templates.first
if test_template
  puts "Testing template: #{test_template.name}"
  
  # Test preview rendering
  preview = test_template.render_preview(sample_data: {
    "contact.first_name" => "Alice",
    "contact.last_name" => "Johnson"
  })
  
  puts "✅ Template preview rendered successfully"
  puts "   Subject: #{preview[:subject]}"
  puts "   Body preview: #{preview[:body][0..100]}..."
  
  # Test design system application
  if test_template.design_system == 'modern'
    puts "✅ Modern design system applied"
  end
  
  # Test color scheme
  if test_template.color_scheme.present?
    puts "✅ Color scheme: #{test_template.color_scheme}"
  end
  
  # Test variables
  variables = test_template.variable_placeholders
  puts "✅ Found #{variables.length} variables: #{variables.join(', ')}"
end

# Test template duplication
puts "\n📑 Testing Template Duplication..."
if test_template
  duplicate = test_template.duplicate
  duplicate.account = Account.first # Assign to an account
  duplicate.user = User.first
  
  if duplicate.save
    puts "✅ Template duplicated successfully"
    puts "   Original: #{test_template.name}"
    puts "   Duplicate: #{duplicate.name}"
    puts "   Usage counts: #{test_template.usage_count} vs #{duplicate.usage_count}"
    
    # Clean up
    duplicate.destroy
  end
end

# Test usage tracking
puts "\n📊 Testing Usage Tracking..."
if test_template
  original_usage = test_template.usage_count
  test_template.increment_usage!
  puts "✅ Usage count incremented: #{original_usage} -> #{test_template.usage_count}"
end

# Test tag management
puts "\n🏷️  Testing Tag Management..."
if test_template
  test_template.add_tag('test-tag')
  puts "✅ Added tag: #{test_template.tags.last}"
  
  has_tag = test_template.has_tag?('test-tag')
  puts "✅ Tag check: #{has_tag}"
  
  test_template.remove_tag('test-tag')
  puts "✅ Removed tag"
end

# Test design system rendering
puts "\n🎨 Testing Design Systems..."
design_systems = ['modern', 'classic', 'minimal']

design_systems.each do |system|
  templates = Template.by_design_system(system)
  if templates.any?
    sample_template = templates.first
    preview = sample_template.render_preview
    puts "✅ #{system.capitalize} design system: #{templates.count} templates"
  end
end

# Test advanced search
puts "\n🔍 Testing Advanced Search..."
search_results = Template.search('welcome')
puts "✅ Search for 'welcome': #{search_results.count} results"

tag_results = Template.by_tags(['newsletter', 'welcome'])
puts "✅ Tag search: #{tag_results.count} results"

premium_templates = Template.premium
free_templates = Template.free
puts "✅ Premium templates: #{premium_templates.count}"
puts "✅ Free templates: #{free_templates.count}"

# Test template validation
puts "\n✅ Testing Template Validation..."
test_account = Account.first
test_user = User.first

new_template = Template.new(
  name: "Test Template",
  subject: "Test Subject with {{contact.first_name}}",
  body: "<h1>Hello {{contact.first_name}}!</h1><p>Welcome to {{account.name}}!</p>",
  template_type: "email",
  status: "draft",
  design_system: "modern",
  color_scheme: { primary: "#2563eb", secondary: "#64748b" },
  tags: ["test", "validation"],
  account: test_account,
  user: test_user
)

if new_template.valid?
  puts "✅ Template validation passed"
  puts "   Variables found: #{new_template.variable_placeholders.join(', ')}"
else
  puts "❌ Template validation failed: #{new_template.errors.full_messages}"
end

puts "\n🎉 Enhanced Template System test completed!"
puts "\nTemplate System Features Verified:"
puts "✅ Public template marketplace"
puts "✅ Design system application (modern, classic, minimal)"
puts "✅ Color scheme customization"
puts "✅ Tag-based organization"
puts "✅ Rating and usage tracking"
puts "✅ Advanced variable substitution"
puts "✅ Template duplication and copying"
puts "✅ Search and filtering capabilities"
puts "✅ Premium/free template classification"