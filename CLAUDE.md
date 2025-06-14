# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup and Development
- `bin/setup` - Initial project setup (installs dependencies, prepares database, starts server)
- `bin/dev` - Start development server with foreman (runs Rails server + Tailwind CSS watcher)
- `bundle install` - Install Ruby dependencies
- `bin/rails db:prepare` - Prepare database (create, migrate, seed)
- `bin/rails db:migrate` - Run database migrations
- `bin/rails db:rollback` - Rollback last migration

### Testing
- `bundle exec rspec` - Run full RSpec test suite
- `bundle exec rspec spec/models/` - Run model tests only
- `bundle exec rspec spec/controllers/` - Run controller tests only
- `bundle exec rspec spec/requests/` - Run request tests only
- `bundle exec rspec spec/path/to/specific_spec.rb` - Run specific test file
- `bundle exec rspec spec/path/to/specific_spec.rb:42` - Run specific test line
- `rails test` - Run Minitest suite (minimal usage)

### Code Quality and Linting
- `bundle exec rubocop` - Run Ruby linter
- `bundle exec rubocop -a` - Auto-fix Ruby style issues
- `bundle exec annotate` - Update model annotations

### Rails Console and Database
- `bin/rails console` or `bin/rails c` - Start Rails console
- `bin/rails dbconsole` or `bin/rails db` - Start database console
- `bin/rails db:seed` - Run database seeds

## Architecture Overview

### Multi-Tenant SaaS Structure
- **Account-based isolation**: Each customer has an Account that serves as the root tenant
- **Subdomain routing**: Accounts are accessed via subdomains (e.g., `customer.rapidmarkt.com`)
- **Role-based access**: Users have roles (owner, admin, member) within accounts
- **Subscription management**: Integrated with Stripe for billing and plan limits

### Core Domain Models
- **Account**: Root tenant with subscription plans and limits
- **User**: Devise authentication with role-based permissions
- **Campaign**: Email marketing campaigns with rich content support
- **Contact**: Customer/subscriber management with tagging system
- **Template**: Reusable email templates
- **Subscription**: Stripe-integrated billing management

### Service Layer Pattern
Key services in `app/services/`:
- **AnalyticsService**: Campaign performance calculations
- **CampaignBroadcastService**: Real-time updates via ActionCable
- **ContactImportService/ContactExportService**: Bulk contact operations
- **TemplateRenderer**: Dynamic template processing

### Frontend Architecture
- **Hotwire**: Turbo + Stimulus for SPA-like experience
- **Tailwind CSS**: Utility-first styling
- **Importmap**: No-build JavaScript management
- **ActionCable**: Real-time features (campaign dashboards)

### Database Architecture
- **PostgreSQL**: Primary database with multi-database production setup
- **Solid Suite**: Database-backed cache, queue, and cable for production
- **Multi-tenancy**: Account-scoped data isolation
- **Comprehensive migrations**: Well-structured schema with proper indexing

### Testing Framework
- **RSpec**: Primary testing framework with comprehensive setup
- **FactoryBot**: Test data generation with realistic factories
- **Capybara + Selenium**: System/integration testing
- **VCR + WebMock**: HTTP interaction testing
- **Devise test helpers**: Authentication testing support

### Authentication & Authorization
- **Devise**: Flexible authentication system
- **Pundit**: Object-oriented authorization
- **Current.account**: Thread-safe account context for multi-tenancy
- **Role-based permissions**: Owner, Admin, Member hierarchy

### Deployment
- **Docker**: Production containerization with multi-stage builds
- **Kamal**: Modern deployment tool for Docker-based apps
- **Thruster**: HTTP caching and compression
- **Let's Encrypt**: SSL certificate management

## Key Patterns and Conventions

### Multi-Tenancy Implementation
- All controllers inherit from `ApplicationController` which sets `Current.account`
- Models use `belongs_to :account` for data isolation
- Subdomain routing handles account resolution
- Plan limits enforced at the service layer

### Real-time Features
- Campaign dashboard updates via ActionCable
- Broadcast service pattern for real-time notifications
- Stimulus controllers for progressive enhancement

### Content Management
- Template system with dynamic rendering
- Rich text support for campaign content
- File uploads handled via Active Storage
- Email tracking via campaign_contacts junction table

### Development Workflow
- Feature branches should be created for new work
- RSpec tests are required for all new functionality
- Follow Rails conventions and existing patterns
- Use service objects for complex business logic