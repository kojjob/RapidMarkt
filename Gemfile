source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.0.2"
# The modern asset pipeline for Rails [https://github.com/rails/propshaft]
gem "propshaft"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Use Tailwind CSS [https://github.com/rails/tailwindcss-rails]
gem "tailwindcss-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Authentication and Authorization
gem "devise" # Flexible authentication solution
gem "pundit" # Minimal authorization through OO design

# SaaS Infrastructure
gem "stripe" # Payment processing

# Content and File Processing
gem "image_processing", "~> 1.2" # Active Storage image variants
gem "friendly_id" # SEO-friendly URLs
gem "kaminari" # Pagination
gem "groupdate" # Date/time grouping for analytics
gem "csv" # CSV parsing
gem "css_parser" # CSS parsing for Tailwind customization
gem "redcarpet" # Markdown rendering
gem "html2text" # HTML to plain text conversion
gem "nokogiri" # HTML/XML parsing
gem "pdfkit" # PDF generation


# API and External Integrations
gem "faraday" # HTTP client library
gem "faraday-retry" # Retry middleware for Faraday

# Monitoring and Performance
gem "rack-mini-profiler" # Performance profiler
gem "memory_profiler" # Memory usage profiler

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
# gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false

  # Testing framework enhancements
  gem "factory_bot_rails" # Test data generation
  gem "faker" # Generate fake data for testing
  gem "rspec-rails" # RSpec testing framework
  gem "shoulda-matchers" # Simple one-liner tests
  gem "vcr" # Record HTTP interactions for tests
  gem "webmock" # Mock HTTP requests
  gem "rails-controller-testing" # Controller testing helpers for assigns and assert_template
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Development productivity tools
  gem "annotate" # Annotate models with schema information
  gem "bullet" # Help to kill N+1 queries and unused eager loading
  gem "letter_opener" # Preview emails in development
  gem "rails-erd" # Generate entity-relationship diagrams
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
end
