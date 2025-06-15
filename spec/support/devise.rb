# Devise test helper configuration
RSpec.configure do |config|
  # Include Devise test helpers
  config.include Devise::Test::ControllerHelpers, type: :controller
  config.include Devise::Test::IntegrationHelpers, type: :request
  config.include Devise::Test::IntegrationHelpers, type: :feature
  config.include Devise::Test::IntegrationHelpers, type: :system

  # Include Rails route helpers for all test types
  config.include Rails.application.routes.url_helpers

  # Warden test helpers for integration tests
  config.include Warden::Test::Helpers

  # Clean up Warden after each test
  config.after(:each) do
    Warden.test_reset!
  end

  # Ensure Devise mappings and routes are properly loaded
  config.before(:suite) do
    # Force complete Rails application reload including routes
    Rails.application.reload_routes!

    # If routes are still empty, there's an issue with the application loading
    if Rails.application.routes.routes.count <= 15  # Only has basic Rails routes
      Rails.logger.warn "Routes not properly loaded, forcing manual load"
      load Rails.root.join("config", "routes.rb")
      Rails.application.reload_routes!
    end

    # Verify Devise mappings are now available
    Rails.logger.info "Total routes loaded: #{Rails.application.routes.routes.count}"
    Rails.logger.info "Devise mappings: #{Devise.mappings.keys}"
  end

  # Also ensure routes are available in each test
  config.before(:each, type: :request) do
    # Make sure routes are loaded for each request test
    if Rails.application.routes.routes.count <= 15
      Rails.application.reload_routes!
    end
  end
end
