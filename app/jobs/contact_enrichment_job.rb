# frozen_string_literal: true

# Job to enrich contact data using external APIs
class ContactEnrichmentJob < ApplicationJob
  include Auditable
  
  queue_as :enrichment
  
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
  retry_on Net::TimeoutError, wait: 1.minute, attempts: 5
  discard_on ActiveRecord::RecordNotFound
  
  # Rate limiting to respect API limits
  rate_limit to: 50, within: 1.minute
  
  def perform(contact_id, enrichment_type = 'full')
    contact = Contact.find(contact_id)
    
    Rails.logger.info "Enriching contact #{contact.id} with type: #{enrichment_type}"
    
    case enrichment_type
    when 'email_validation'
      validate_email(contact)
    when 'social_profiles'
      enrich_social_profiles(contact)
    when 'company_data'
      enrich_company_data(contact)
    when 'demographics'
      enrich_demographics(contact)
    when 'full'
      validate_email(contact)
      enrich_social_profiles(contact)
      enrich_company_data(contact)
      enrich_demographics(contact)
    end
    
    # Update last enrichment timestamp
    contact.update!(
      last_enriched_at: Time.current,
      enrichment_status: 'completed'
    )
    
    Rails.logger.info "Contact #{contact.id} enrichment completed"
    
  rescue => error
    contact.update!(
      enrichment_status: 'failed',
      enrichment_error: error.message
    )
    
    Rails.logger.error "Contact enrichment failed for #{contact.id}: #{error.message}"
    raise error
  end
  
  private
  
  def validate_email(contact)
    # Validate email deliverability
    validation_result = EmailValidationService.validate(contact.email)
    
    enrichment_data = contact.enrichment_data || {}
    enrichment_data['email_validation'] = {
      is_valid: validation_result[:valid],
      is_deliverable: validation_result[:deliverable],
      risk_level: validation_result[:risk_level],
      provider: validation_result[:provider],
      validated_at: Time.current
    }
    
    # Update contact status if email is invalid
    if !validation_result[:valid] && contact.status == 'subscribed'
      contact.update!(
        status: 'bounced',
        bounced_at: Time.current,
        bounce_reason: 'Invalid email detected during enrichment'
      )
    end
    
    contact.update!(enrichment_data: enrichment_data)
  end
  
  def enrich_social_profiles(contact)
    # Use a service like FullContact or Clearbit to get social profiles
    social_data = SocialEnrichmentService.lookup(contact.email)
    
    if social_data[:success]
      enrichment_data = contact.enrichment_data || {}
      enrichment_data['social_profiles'] = {
        linkedin: social_data[:linkedin],
        twitter: social_data[:twitter],
        facebook: social_data[:facebook],
        github: social_data[:github],
        avatar_url: social_data[:avatar_url],
        enriched_at: Time.current
      }
      
      # Update contact avatar if found
      if social_data[:avatar_url] && contact.avatar_url.blank?
        contact.update!(avatar_url: social_data[:avatar_url])
      end
      
      contact.update!(enrichment_data: enrichment_data)
    end
  end
  
  def enrich_company_data(contact)
    # Skip if no company info available
    return unless contact.company.present? || extract_company_from_email(contact.email)
    
    company_domain = extract_company_from_email(contact.email)
    company_name = contact.company || company_domain
    
    company_data = CompanyEnrichmentService.lookup(company_name, company_domain)
    
    if company_data[:success]
      enrichment_data = contact.enrichment_data || {}
      enrichment_data['company_data'] = {
        name: company_data[:name],
        domain: company_data[:domain],
        industry: company_data[:industry],
        size: company_data[:size],
        location: company_data[:location],
        founded_year: company_data[:founded_year],
        description: company_data[:description],
        logo_url: company_data[:logo_url],
        enriched_at: Time.current
      }
      
      # Update contact company info if blank
      if contact.company.blank? && company_data[:name]
        contact.update!(company: company_data[:name])
      end
      
      contact.update!(enrichment_data: enrichment_data)
      
      # Add company tags
      add_company_tags(contact, company_data)
    end
  end
  
  def enrich_demographics(contact)
    # Get demographic data from name and location
    demographic_data = DemographicEnrichmentService.analyze(
      first_name: contact.first_name,
      last_name: contact.last_name,
      location: contact.location
    )
    
    if demographic_data[:success]
      enrichment_data = contact.enrichment_data || {}
      enrichment_data['demographics'] = {
        likely_gender: demographic_data[:gender],
        likely_age_range: demographic_data[:age_range],
        likely_country: demographic_data[:country],
        likely_timezone: demographic_data[:timezone],
        confidence_score: demographic_data[:confidence],
        enriched_at: Time.current
      }
      
      contact.update!(enrichment_data: enrichment_data)
      
      # Update contact timezone if detected and not set
      if contact.timezone.blank? && demographic_data[:timezone]
        contact.update!(timezone: demographic_data[:timezone])
      end
    end
  end
  
  def extract_company_from_email(email)
    domain = email.split('@').last
    return nil if domain.blank?
    
    # Skip common email providers
    common_providers = %w[
      gmail.com yahoo.com hotmail.com outlook.com
      aol.com icloud.com me.com mac.com
      protonmail.com tutanota.com
    ]
    
    return nil if common_providers.include?(domain.downcase)
    
    domain
  end
  
  def add_company_tags(contact, company_data)
    tags_to_add = []
    
    # Industry tags
    if company_data[:industry]
      tags_to_add << "Industry: #{company_data[:industry]}"
    end
    
    # Company size tags
    case company_data[:size]
    when 1..10
      tags_to_add << "Company Size: Startup"
    when 11..50
      tags_to_add << "Company Size: Small Business"
    when 51..200
      tags_to_add << "Company Size: Medium Business"
    when 201..1000
      tags_to_add << "Company Size: Large Business"
    else
      tags_to_add << "Company Size: Enterprise"
    end
    
    # Location tags
    if company_data[:location]
      tags_to_add << "Company Location: #{company_data[:location]}"
    end
    
    # Add tags to contact
    tags_to_add.each do |tag_name|
      tag = contact.account.tags.find_or_create_by(name: tag_name)
      contact.tags << tag unless contact.tags.include?(tag)
    end
  end
end

# Mock services for demonstration - these would integrate with real APIs

class EmailValidationService
  def self.validate(email)
    # This would integrate with services like ZeroBounce, NeverBounce, etc.
    {
      valid: email.match?(URI::MailTo::EMAIL_REGEXP),
      deliverable: true, # Would check with actual service
      risk_level: 'low',
      provider: email.split('@').last
    }
  end
end

class SocialEnrichmentService
  def self.lookup(email)
    # This would integrate with FullContact, Clearbit, etc.
    {
      success: false, # Would return actual data
      linkedin: nil,
      twitter: nil,
      facebook: nil,
      github: nil,
      avatar_url: nil
    }
  end
end

class CompanyEnrichmentService
  def self.lookup(company_name, domain)
    # This would integrate with Clearbit, Hunter.io, etc.
    {
      success: false, # Would return actual data
      name: company_name,
      domain: domain,
      industry: nil,
      size: nil,
      location: nil,
      founded_year: nil,
      description: nil,
      logo_url: nil
    }
  end
end

class DemographicEnrichmentService
  def self.analyze(first_name:, last_name:, location:)
    # This would integrate with services for demographic analysis
    {
      success: false, # Would return actual data
      gender: nil,
      age_range: nil,
      country: nil,
      timezone: nil,
      confidence: 0
    }
  end
end
