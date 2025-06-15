# frozen_string_literal: true

class ContactManagementService
  include ActiveModel::Model
  include ActiveModel::Attributes
  
  attr_reader :account, :errors

  def initialize(account:)
    @account = account
    @errors = ActiveModel::Errors.new(self)
  end

  # Bulk import contacts with validation and deduplication
  def bulk_import(contacts_data, options = {})
    import_results = {
      total_processed: 0,
      successful_imports: 0,
      failed_imports: 0,
      duplicates_found: 0,
      errors: [],
      warnings: [],
      imported_contacts: []
    }

    ApplicationRecord.transaction do
      contacts_data.each_with_index do |contact_data, index|
        import_results[:total_processed] += 1
        
        result = import_single_contact(contact_data, options)
        
        if result.success?
          import_results[:successful_imports] += 1
          import_results[:imported_contacts] << result.data
        else
          import_results[:failed_imports] += 1
          import_results[:errors] << {
            row: index + 1,
            email: contact_data[:email],
            errors: result.errors
          }
        end
      end
      
      # Generate import summary
      audit_log("Bulk import completed: #{import_results[:successful_imports]} successful, #{import_results[:failed_imports]} failed")
      
      Result.success(import_results)
    end
  rescue => e
    Rails.logger.error "Bulk import failed: #{e.message}"
    Result.failure("Bulk import failed: #{e.message}")
  end

  # Smart contact segmentation
  def create_smart_segment(segment_params)
    segment_name = segment_params[:name]
    conditions = segment_params[:conditions] || []
    
    # Build dynamic query based on conditions
    query = build_segment_query(conditions)
    
    # Execute query to get matching contacts
    matching_contacts = @account.contacts.where(query[:sql], *query[:params])
    
    # Create or update tag for this segment
    segment_tag = @account.tags.find_or_create_by(name: segment_name) do |tag|
      tag.color = segment_params[:color] || '#007bff'  
      tag.description = "Smart segment: #{segment_params[:description]}"
      tag.is_smart_segment = true
      tag.segment_conditions = conditions
    end
    
    # Apply tag to matching contacts
    ApplicationRecord.transaction do
      # Clear existing segment assignments
      segment_tag.contact_tags.destroy_all
      
      # Add new assignments
      matching_contacts.find_each do |contact|
        segment_tag.contact_tags.create!(contact: contact)
      end
      
      segment_tag.update!(contacts_count: matching_contacts.count)
      
      audit_log("Smart segment '#{segment_name}' created with #{matching_contacts.count} contacts")
      
      Result.success({
        segment: segment_tag,
        contacts_count: matching_contacts.count,
        contacts: matching_contacts.limit(100) # Return first 100 for preview
      })
    end
  rescue => e
    Rails.logger.error "Smart segment creation failed: #{e.message}"
    Result.failure("Failed to create smart segment: #{e.message}")
  end

  # Contact engagement scoring
  def calculate_engagement_scores
    @account.contacts.find_each do |contact|
      score = EngagementScoreCalculator.new(contact).calculate
      contact.update_column(:engagement_score, score)
    end
    
    # Update engagement segments
    update_engagement_segments
    
    audit_log("Engagement scores calculated for all contacts")
    Result.success("Engagement scores updated successfully")
  end

  # Contact lifecycle management
  def update_contact_lifecycle_stage(contact, stage, reason = nil)
    valid_stages = %w[lead prospect customer advocate churned]
    
    return Result.failure("Invalid lifecycle stage") unless valid_stages.include?(stage)
    
    old_stage = contact.lifecycle_stage
    
    if contact.update(lifecycle_stage: stage, lifecycle_updated_at: Time.current)
      # Log lifecycle change
      contact.contact_lifecycle_logs.create!(
        from_stage: old_stage,
        to_stage: stage,
        reason: reason,
        user: Current.user
      )
      
      # Trigger lifecycle-based automations
      trigger_lifecycle_automations(contact, stage, old_stage)
      
      audit_log("Contact #{contact.email} moved from #{old_stage} to #{stage}")
      Result.success(contact)
    else
      Result.failure(contact.errors)
    end
  end

  # Contact health check and cleanup
  def perform_health_check
    health_report = {
      total_contacts: @account.contacts.count,
      active_contacts: @account.contacts.subscribed.count,
      inactive_contacts: @account.contacts.unsubscribed.count,
      bounced_contacts: @account.contacts.bounced.count,
      issues_found: [],
      cleanup_suggestions: []
    }

    # Check for duplicate emails
    duplicates = find_duplicate_contacts
    if duplicates.any?
      health_report[:issues_found] << {
        type: 'duplicates',
        count: duplicates.count,
        details: duplicates.first(10)
      }
      health_report[:cleanup_suggestions] << "Merge or remove duplicate contacts"
    end

    # Check for invalid email formats
    invalid_emails = find_invalid_email_contacts
    if invalid_emails.any?
      health_report[:issues_found] << {
        type: 'invalid_emails',
        count: invalid_emails.count,
        details: invalid_emails.first(10)
      }
      health_report[:cleanup_suggestions] << "Review and fix invalid email addresses"
    end

    # Check for stale contacts (no engagement in 6+ months)
    stale_contacts = find_stale_contacts
    if stale_contacts.any?
      health_report[:issues_found] << {
        type: 'stale_contacts',
        count: stale_contacts.count
      }
      health_report[:cleanup_suggestions] << "Consider re-engagement campaign for stale contacts"
    end

    # Check for contacts with missing essential data
    incomplete_contacts = find_incomplete_contacts
    if incomplete_contacts.any?
      health_report[:issues_found] << {
        type: 'incomplete_data',
        count: incomplete_contacts.count
      }
      health_report[:cleanup_suggestions] << "Complete missing contact information"
    end

    Result.success(health_report)
  end

  # Automated contact cleanup
  def perform_automated_cleanup(options = {})
    cleanup_results = {
      duplicates_merged: 0,
      invalid_emails_fixed: 0,
      stale_contacts_archived: 0,
      total_cleaned: 0
    }

    ApplicationRecord.transaction do
      # Merge duplicates if requested
      if options[:merge_duplicates]
        duplicates = find_duplicate_contacts
        duplicates.each do |duplicate_group|
          merge_result = merge_duplicate_contacts(duplicate_group)
          cleanup_results[:duplicates_merged] += 1 if merge_result.success?
        end
      end

      # Archive stale contacts if requested
      if options[:archive_stale_contacts]
        stale_contacts = find_stale_contacts
        stale_contacts.update_all(
          status: 'archived',
          archived_at: Time.current,
          archived_reason: 'Automated cleanup - no engagement for 6+ months'
        )
        cleanup_results[:stale_contacts_archived] = stale_contacts.count
      end

      cleanup_results[:total_cleaned] = cleanup_results.values.sum
      
      audit_log("Automated cleanup completed: #{cleanup_results[:total_cleaned]} actions taken")
      Result.success(cleanup_results)
    end
  rescue => e
    Rails.logger.error "Automated cleanup failed: #{e.message}"
    Result.failure("Cleanup failed: #{e.message}")
  end

  # Contact enrichment from external sources
  def enrich_contact_data(contact, sources = [:clearbit, :fullcontact])
    enrichment_results = {
      original_data: contact.attributes.slice('first_name', 'last_name', 'company', 'job_title', 'location'),
      enriched_data: {},
      sources_used: [],
      success: false
    }

    sources.each do |source|
      begin
        case source
        when :clearbit
          data = enrich_from_clearbit(contact)
        when :fullcontact
          data = enrich_from_fullcontact(contact)
        else
          next
        end

        if data.present?
          enrichment_results[:enriched_data].merge!(data)
          enrichment_results[:sources_used] << source
        end
      rescue => e
        Rails.logger.warn "Enrichment from #{source} failed: #{e.message}"
      end
    end

    # Apply enriched data to contact
    if enrichment_results[:enriched_data].any?
      contact.update!(enrichment_results[:enriched_data])
      contact.update!(last_enriched_at: Time.current)
      
      enrichment_results[:success] = true
      audit_log("Contact #{contact.email} enriched from #{enrichment_results[:sources_used].join(', ')}")
    end

    Result.success(enrichment_results)
  end

  # Contact preference management
  def update_contact_preferences(contact, preferences)
    preference_updates = {}
    
    # Email frequency preferences
    if preferences[:email_frequency].present?
      preference_updates[:email_frequency] = preferences[:email_frequency]
    end
    
    # Content type preferences
    if preferences[:content_types].present?
      preference_updates[:preferred_content_types] = preferences[:content_types]
    end
    
    # Communication channel preferences
    if preferences[:channels].present?
      preference_updates[:preferred_channels] = preferences[:channels]
    end
    
    if contact.update(preference_updates)
      audit_log("Preferences updated for contact #{contact.email}")
      Result.success(contact)
    else
      Result.failure(contact.errors)
    end
  end

  private

  def import_single_contact(contact_data, options)
    # Normalize and validate email
    email = contact_data[:email]&.strip&.downcase
    return Result.failure("Email is required") if email.blank?
    return Result.failure("Invalid email format") unless email.match?(URI::MailTo::EMAIL_REGEXP)

    # Check for duplicates
    existing_contact = @account.contacts.find_by(email: email)
    
    if existing_contact
      if options[:update_duplicates]
        # Update existing contact
        if existing_contact.update(contact_data.except(:email))
          return Result.success(existing_contact)
        else
          return Result.failure(existing_contact.errors)
        end
      else
        return Result.failure("Contact with email #{email} already exists")
      end
    end

    # Create new contact
    contact = @account.contacts.build(contact_data)
    contact.status = 'subscribed' unless contact.status.present?
    contact.subscribed_at = Time.current if contact.status == 'subscribed'
    
    if contact.save
      # Apply default tags if specified
      if options[:default_tags].present?
        apply_tags_to_contact(contact, options[:default_tags])
      end
      
      Result.success(contact)
    else
      Result.failure(contact.errors)
    end
  end

  def build_segment_query(conditions)
    sql_parts = []
    params = []
    
    conditions.each do |condition|
      case condition[:field]
      when 'status'
        sql_parts << "status = ?"
        params << condition[:value]
      when 'created_at'
        case condition[:operator]
        when 'after'
          sql_parts << "created_at > ?"
          params << Date.parse(condition[:value])
        when 'before'
          sql_parts << "created_at < ?"
          params << Date.parse(condition[:value])
        end
      when 'engagement_score'
        case condition[:operator]
        when 'greater_than'
          sql_parts << "engagement_score > ?"
          params << condition[:value].to_i
        when 'less_than'
          sql_parts << "engagement_score < ?"
          params << condition[:value].to_i
        end
      when 'tags'
        if condition[:operator] == 'includes'
          sql_parts << "id IN (SELECT contact_id FROM contact_tags JOIN tags ON contact_tags.tag_id = tags.id WHERE tags.name = ?)"
          params << condition[:value]
        end
      when 'last_opened_at'
        case condition[:operator]
        when 'after'
          sql_parts << "last_opened_at > ?"
          params << Date.parse(condition[:value])
        when 'before'
          sql_parts << "last_opened_at < ?"
          params << Date.parse(condition[:value])
        when 'is_null'
          sql_parts << "last_opened_at IS NULL"
        end
      end
    end
    
    {
      sql: sql_parts.join(' AND '),
      params: params
    }
  end

  def update_engagement_segments
    # Update high engagement segment
    high_engagement = @account.contacts.where('engagement_score >= ?', 80)
    update_segment_tag('High Engagement', high_engagement)
    
    # Update low engagement segment
    low_engagement = @account.contacts.where('engagement_score <= ?', 20)
    update_segment_tag('Low Engagement', low_engagement)
    
    # Update medium engagement segment
    medium_engagement = @account.contacts.where(engagement_score: 21..79)
    update_segment_tag('Medium Engagement', medium_engagement)
  end

  def update_segment_tag(name, contacts)
    tag = @account.tags.find_or_create_by(name: name) do |t|
      t.is_smart_segment = true
      t.color = case name
                when 'High Engagement' then '#28a745'
                when 'Medium Engagement' then '#ffc107'
                when 'Low Engagement' then '#dc3545'
                end
    end
    
    # Clear existing assignments
    tag.contact_tags.destroy_all
    
    # Add new assignments
    contacts.find_each do |contact|
      tag.contact_tags.create!(contact: contact)
    end
    
    tag.update!(contacts_count: contacts.count)
  end

  def trigger_lifecycle_automations(contact, new_stage, old_stage)
    # This would trigger various automations based on lifecycle changes
    case new_stage
    when 'customer'
      # Send welcome customer email
      # Add to customer onboarding sequence
    when 'advocate'
      # Send thank you email
      # Add to referral program
    when 'churned'
      # Send win-back campaign
      # Remove from active campaigns
    end
  end

  def find_duplicate_contacts
    @account.contacts
            .select(:email)
            .group(:email)
            .having('COUNT(*) > 1')
            .pluck(:email)
            .map { |email| @account.contacts.where(email: email) }
  end

  def find_invalid_email_contacts
    @account.contacts.where.not(email: nil)
            .select { |c| !c.email.match?(URI::MailTo::EMAIL_REGEXP) }
  end

  def find_stale_contacts
    @account.contacts.where('last_opened_at < ? OR (last_opened_at IS NULL AND created_at < ?)', 
                           6.months.ago, 6.months.ago)
  end

  def find_incomplete_contacts
    @account.contacts.where(
      '(first_name IS NULL OR first_name = ?) OR (last_name IS NULL OR last_name = ?)',
      '', ''
    )
  end

  def merge_duplicate_contacts(duplicate_contacts)
    # Keep the oldest contact as the primary
    primary_contact = duplicate_contacts.order(:created_at).first
    duplicate_contacts_to_merge = duplicate_contacts.where.not(id: primary_contact.id)
    
    ApplicationRecord.transaction do
      duplicate_contacts_to_merge.each do |duplicate|
        # Merge campaign associations
        duplicate.campaign_contacts.update_all(contact_id: primary_contact.id)
        
        # Merge tags (avoid duplicates)
        duplicate.tags.each do |tag|
          unless primary_contact.tags.include?(tag)
            primary_contact.tags << tag
          end
        end
        
        # Update primary contact with any missing information
        update_attrs = {}
        update_attrs[:first_name] = duplicate.first_name if primary_contact.first_name.blank? && duplicate.first_name.present?
        update_attrs[:last_name] = duplicate.last_name if primary_contact.last_name.blank? && duplicate.last_name.present?
        update_attrs[:company] = duplicate.company if primary_contact.company.blank? && duplicate.company.present?
        
        primary_contact.update!(update_attrs) if update_attrs.any?
        
        # Delete the duplicate
        duplicate.destroy!
      end
      
      Result.success(primary_contact)
    end
  rescue => e
    Rails.logger.error "Contact merge failed: #{e.message}"
    Result.failure("Failed to merge contacts: #{e.message}")
  end

  def enrich_from_clearbit(contact)
    # Placeholder for Clearbit API integration
    # This would make API calls to enrich contact data
    {}
  end

  def enrich_from_fullcontact(contact)
    # Placeholder for FullContact API integration
    # This would make API calls to enrich contact data
    {}
  end

  def apply_tags_to_contact(contact, tag_names)
    tag_names.each do |tag_name|
      tag = @account.tags.find_or_create_by(name: tag_name)
      contact.tags << tag unless contact.tags.include?(tag)
    end
  end

  def audit_log(message)
    @account.audit_logs.create!(
      user: Current.user,
      action: 'contact_management',
      details: message,
      resource_type: 'Contact'
    )
  rescue => e
    Rails.logger.warn "Failed to create audit log: #{e.message}"
  end

  # Engagement score calculator
  class EngagementScoreCalculator
    def initialize(contact)
      @contact = contact
    end

    def calculate
      score = 0
      
      # Base score for being subscribed
      score += 10 if @contact.subscribed?
      
      # Points for recent activity
      if @contact.last_opened_at.present?
        days_since_last_open = (Date.current - @contact.last_opened_at.to_date).to_i
        if days_since_last_open < 7
          score += 30
        elsif days_since_last_open < 30
          score += 20
        elsif days_since_last_open < 90
          score += 10
        end
      end
      
      # Points for click activity
      if @contact.last_clicked_at.present?
        days_since_last_click = (Date.current - @contact.last_clicked_at.to_date).to_i
        if days_since_last_click < 7
          score += 25
        elsif days_since_last_click < 30
          score += 15
        elsif days_since_last_click < 90
          score += 5
        end
      end
      
      # Points for profile completeness
      score += 5 if @contact.first_name.present?
      score += 5 if @contact.last_name.present?
      score += 5 if @contact.company.present?
      score += 5 if @contact.job_title.present?
      
      # Points for being a customer
      score += 20 if @contact.lifecycle_stage == 'customer'
      
      # Cap the score at 100
      [score, 100].min
    end
  end

  # Result class for consistent return values
  class Result
    attr_reader :data, :errors, :success

    def initialize(success:, data: nil, errors: nil)
      @success = success
      @data = data
      @errors = errors
    end

    def self.success(data = nil)
      new(success: true, data: data)
    end

    def self.failure(errors)
      new(success: false, errors: errors)
    end

    def success?
      @success
    end

    def failure?
      !@success
    end
  end
end
