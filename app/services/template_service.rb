# frozen_string_literal: true

class TemplateService
  include ActiveModel::Model
  include ActiveModel::Attributes

  attr_reader :template, :account, :errors

  def initialize(template: nil, account: nil)
    @template = template
    @account = account || template&.account
    @errors = ActiveModel::Errors.new(self)
  end

  # Create template with validation and component processing
  def create(params)
    @template = @account.templates.build(params.except(:components, :design_config))

    ApplicationRecord.transaction do
      if @template.save
        # Process and save template components if provided
        if params[:components].present?
          process_template_components(params[:components])
        end

        # Save design configuration
        if params[:design_config].present?
          save_design_configuration(params[:design_config])
        end

        # Generate template preview
        generate_preview_images

        audit_log("Template '#{@template.name}' created")
        Result.success(@template)
      else
        @errors.merge!(@template.errors)
        Result.failure(@errors)
      end
    end
  rescue => e
    Rails.logger.error "Template creation failed: #{e.message}"
    @errors.add(:base, "Failed to create template: #{e.message}")
    Result.failure(@errors)
  end

  # Advanced template rendering with personalization
  def render_for_contact(contact, options = {})
    return Result.failure("Template not found") unless @template
    return Result.failure("Contact not found") unless contact

    begin
      # Build context for template rendering
      context = build_rendering_context(contact, options)

      # Render subject and body with advanced interpolation
      rendered_subject = advanced_interpolate(@template.subject, context)
      rendered_body = advanced_interpolate(@template.body, context)

      # Apply personalization rules
      if options[:personalization_enabled]
        rendered_subject = apply_personalization(rendered_subject, contact)
        rendered_body = apply_personalization(rendered_body, contact)
      end

      # Track rendering for analytics
      track_template_render(contact, options)

      result = {
        subject: rendered_subject,
        body: rendered_body,
        preview_text: extract_preview_text(rendered_body),
        tracking_pixel: generate_tracking_pixel(contact),
        unsubscribe_link: generate_unsubscribe_link(contact)
      }

      Result.success(result)
    rescue => e
      Rails.logger.error "Template rendering failed: #{e.message}"
      Result.failure("Template rendering failed: #{e.message}")
    end
  end

  # Clone template with advanced options
  def clone(options = {})
    new_template = @template.dup
    new_template.name = options[:name] || "#{@template.name} (Copy)"
    new_template.status = options[:status] || "draft"

    # Clone design components if they exist
    if @template.design_config.present?
      new_template.design_config = @template.design_config.deep_dup
    end

    ApplicationRecord.transaction do
      if new_template.save
        # Copy any associated files or assets
        copy_template_assets(new_template) if options[:copy_assets]

        audit_log("Template '#{@template.name}' cloned as '#{new_template.name}'")
        Result.success(new_template)
      else
        Result.failure(new_template.errors)
      end
    end
  rescue => e
    Rails.logger.error "Template cloning failed: #{e.message}"
    Result.failure("Failed to clone template: #{e.message}")
  end

  # Validate template with comprehensive checks
  def validate_template
    validation_results = {
      valid: true,
      warnings: [],
      errors: [],
      suggestions: []
    }

    # Check for required elements
    validation_results = check_required_elements(validation_results)

    # Validate HTML structure
    validation_results = validate_html_structure(validation_results)

    # Check for accessibility issues
    validation_results = check_accessibility(validation_results)

    # Validate email deliverability factors
    validation_results = check_deliverability(validation_results)

    # Check for personalization variables
    validation_results = validate_personalization_variables(validation_results)

    validation_results[:valid] = validation_results[:errors].empty?

    Result.success(validation_results)
  end

  # Generate template performance insights
  def performance_insights
    return Result.failure("Template has no campaign history") unless @template.campaigns.any?

    campaigns = @template.campaigns.sent

    insights = {
      usage_stats: calculate_usage_stats(campaigns),
      performance_metrics: calculate_performance_metrics(campaigns),
      optimization_suggestions: generate_optimization_suggestions(campaigns),
      comparative_analysis: comparative_analysis(campaigns),
      best_performing_versions: best_performing_versions(campaigns)
    }

    Result.success(insights)
  end

  # A/B test different template versions
  def create_ab_test_variant(variant_params)
    variant_template = @template.dup
    variant_template.name = "#{@template.name} (A/B Test)"
    variant_template.assign_attributes(variant_params)
    variant_template.ab_test_original_id = @template.id

    if variant_template.save
      @template.update!(ab_test_enabled: true)
      audit_log("A/B test variant created for template '#{@template.name}'")
      Result.success(variant_template)
    else
      Result.failure(variant_template.errors)
    end
  end

  # Export template in various formats
  def export(format = "html")
    case format.downcase
    when "html"
      export_html
    when "json"
      export_json
    when "mjml"
      export_mjml
    when "pdf"
      export_pdf
    else
      Result.failure("Unsupported export format: #{format}")
    end
  end

  private

  def process_template_components(components)
    # Process drag-and-drop components and convert to template structure
    processed_components = components.map do |component|
      {
        type: component[:type],
        properties: component[:properties] || {},
        styles: component[:styles] || {},
        content: component[:content] || "",
        position: component[:position] || {}
      }
    end

    # Store components configuration
    @template.update!(
      design_config: {
        components: processed_components,
        layout: extract_layout_info(components),
        theme: extract_theme_info(components)
      }
    )
  end

  def save_design_configuration(config)
    current_config = @template.design_config || {}
    merged_config = current_config.deep_merge(config)
    @template.update!(design_config: merged_config)
  end

  def generate_preview_images
    # Generate thumbnail and preview images for template
    # This would integrate with image generation service
    Rails.logger.info "Generating preview images for template #{@template.id}"
  end

  def build_rendering_context(contact, options)
    {
      contact: {
        first_name: contact.first_name || "",
        last_name: contact.last_name || "",
        email: contact.email,
        full_name: contact.full_name,
        tags: contact.tags.pluck(:name),
        custom_fields: contact.custom_fields || {}
      },
      account: {
        name: @account.name,
        website: @account.website,
        logo_url: @account.logo_url,
        contact_info: @account.contact_info || {}
      },
      campaign: options[:campaign] ? build_campaign_context(options[:campaign]) : {},
      system: {
        current_date: Date.current.strftime("%B %d, %Y"),
        current_year: Date.current.year,
        current_month: Date.current.strftime("%B"),
        current_day: Date.current.day
      }
    }
  end

  def build_campaign_context(campaign)
    {
      name: campaign.name,
      subject: campaign.subject,
      from_name: campaign.from_name,
      from_email: campaign.from_email,
      reply_to: campaign.reply_to
    }
  end

  def advanced_interpolate(content, context)
    return content if content.blank?

    # Handle nested object access (e.g., contact.custom_fields.company)
    content.gsub(/\{\{\s*([^}]+)\s*\}\}/) do |match|
      variable_path = $1.strip
      resolve_nested_variable(variable_path, context) || match
    end
  end

  def resolve_nested_variable(path, context)
    keys = path.split(".")
    value = context

    keys.each do |key|
      if value.is_a?(Hash)
        value = value[key.to_sym] || value[key.to_s]
      else
        return nil
      end

      return nil if value.nil?
    end

    value.to_s
  end

  def apply_personalization(content, contact)
    # Apply AI-driven personalization based on contact data
    # This would integrate with personalization engine
    content
  end

  def extract_preview_text(body)
    # Extract first 150 characters of plain text as preview
    ActionView::Base.full_sanitizer.sanitize(body).truncate(150)
  end

  def generate_tracking_pixel(contact)
    # Generate tracking pixel URL for open tracking
    "#{Rails.application.routes.url_helpers.root_url}track/open/#{contact.id}?template=#{@template.id}"
  end

  def generate_unsubscribe_link(contact)
    # Generate unsubscribe link
    Rails.application.routes.url_helpers.unsubscribe_url(
      token: contact.unsubscribe_token,
      host: Rails.application.config.action_mailer.default_url_options[:host]
    )
  end

  def track_template_render(contact, options)
    # Track template rendering for analytics
    Rails.logger.info "Template #{@template.id} rendered for contact #{contact.id}"
  end

  def check_required_elements(results)
    # Check for essential email elements
    if @template.body.blank?
      results[:errors] << "Template body is required"
    end

    if @template.subject.blank?
      results[:errors] << "Template subject is required"
    end

    # Check for unsubscribe link
    unless @template.body.include?("unsubscribe") || @template.body.include?("{{unsubscribe_url}}")
      results[:warnings] << "Template should include an unsubscribe link"
    end

    results
  end

  def validate_html_structure(results)
    # Basic HTML validation
    if @template.body.include?("<html") && !@template.body.include?("</html>")
      results[:errors] << "Malformed HTML structure detected"
    end

    results
  end

  def check_accessibility(results)
    # Check for accessibility issues
    if @template.body.include?("<img") && !@template.body.include?("alt=")
      results[:warnings] << "Images should have alt text for accessibility"
    end

    results
  end

  def check_deliverability(results)
    # Check factors that affect email deliverability
    if @template.body.length > 102400 # 100KB
      results[:warnings] << "Template is quite large and may be truncated by email clients"
    end

    # Check for spam triggers
    spam_words = [ "free", "urgent", "act now", "limited time" ]
    spam_found = spam_words.any? { |word| @template.body.downcase.include?(word) }

    if spam_found
      results[:suggestions] << "Consider reviewing content for potential spam triggers"
    end

    results
  end

  def validate_personalization_variables(results)
    # Check for undefined variables
    variables = @template.variable_placeholders

    variables.each do |var|
      unless var.match?(/^(contact|account|system|campaign)\./)
        results[:warnings] << "Variable '#{var}' may not be defined"
      end
    end

    results
  end

  def calculate_usage_stats(campaigns)
    {
      total_campaigns: campaigns.count,
      total_sends: campaigns.sum { |c| c.total_recipients },
      average_monthly_usage: campaigns.group_by_month(:created_at).count.values.sum / 12.0,
      most_recent_use: campaigns.maximum(:created_at)
    }
  end

  def calculate_performance_metrics(campaigns)
    {
      average_open_rate: campaigns.average(:open_rate) || 0,
      average_click_rate: campaigns.average(:click_rate) || 0,
      best_open_rate: campaigns.maximum(:open_rate) || 0,
      best_click_rate: campaigns.maximum(:click_rate) || 0,
      performance_trend: calculate_performance_trend(campaigns)
    }
  end

  def calculate_performance_trend(campaigns)
    # Calculate performance trend over time
    recent_campaigns = campaigns.where("created_at > ?", 3.months.ago)
    older_campaigns = campaigns.where("created_at <= ?", 3.months.ago)

    recent_avg = recent_campaigns.average(:open_rate) || 0
    older_avg = older_campaigns.average(:open_rate) || 0

    if older_avg > 0
      ((recent_avg - older_avg) / older_avg * 100).round(2)
    else
      0
    end
  end

  def generate_optimization_suggestions(campaigns)
    suggestions = []

    avg_open_rate = campaigns.average(:open_rate) || 0
    avg_click_rate = campaigns.average(:click_rate) || 0

    if avg_open_rate < 20
      suggestions << "Consider A/B testing different subject lines to improve open rates"
    end

    if avg_click_rate < 2
      suggestions << "Try adding more compelling calls-to-action to improve click rates"
    end

    if @template.body.length < 200
      suggestions << "Consider adding more content to provide value to recipients"
    end

    suggestions
  end

  def comparative_analysis(campaigns)
    # Compare with account averages
    account_avg_open = @account.campaigns.sent.average(:open_rate) || 0
    template_avg_open = campaigns.average(:open_rate) || 0

    {
      vs_account_average: {
        open_rate_difference: (template_avg_open - account_avg_open).round(2),
        performance_category: template_avg_open > account_avg_open ? "above_average" : "below_average"
      }
    }
  end

  def best_performing_versions(campaigns)
    campaigns.order(open_rate: :desc).limit(3).map do |campaign|
      {
        campaign_id: campaign.id,
        campaign_name: campaign.name,
        open_rate: campaign.open_rate,
        click_rate: campaign.click_rate,
        sent_at: campaign.sent_at
      }
    end
  end

  def copy_template_assets(new_template)
    # Copy any associated files or images
    # This would integrate with file storage system
    Rails.logger.info "Copying assets for template #{new_template.id}"
  end

  def extract_layout_info(components)
    # Extract layout information from components
    {
      columns: components.count { |c| c[:type] == "column" },
      sections: components.count { |c| c[:type] == "section" },
      structure: "single_column" # This would be more sophisticated
    }
  end

  def extract_theme_info(components)
    # Extract theme information
    {
      primary_color: "#007bff",
      font_family: "Arial, sans-serif",
      font_size: "14px"
    }
  end

  def export_html
    Result.success(@template.body)
  end

  def export_json
    data = {
      name: @template.name,
      subject: @template.subject,
      body: @template.body,
      template_type: @template.template_type,
      design_config: @template.design_config,
      created_at: @template.created_at,
      updated_at: @template.updated_at
    }

    Result.success(data.to_json)
  end

  def export_mjml
    # Convert HTML to MJML format
    # This would require MJML conversion library
    Result.success("MJML export not implemented yet")
  end

  def export_pdf
    # Generate PDF version of template
    # This would require PDF generation library
    Result.success("PDF export not implemented yet")
  end

  def audit_log(message)
    @account.audit_logs.create!(
      user: Current.user,
      action: "template_operation",
      details: message,
      resource_type: "Template",
      resource_id: @template.id
    )
  rescue => e
    Rails.logger.warn "Failed to create audit log: #{e.message}"
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
