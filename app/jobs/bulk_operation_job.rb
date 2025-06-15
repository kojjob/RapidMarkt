# frozen_string_literal: true

# Job to handle bulk operations on contacts, campaigns, and automations
class BulkOperationJob < ApplicationJob
  include Auditable

  queue_as :bulk_operations

  retry_on StandardError, wait: :exponentially_longer, attempts: 2
  discard_on ActiveRecord::RecordNotFound

  def perform(operation_type, model_type, record_ids, options = {})
    Rails.logger.info "Starting bulk operation: #{operation_type} on #{model_type} for #{record_ids.count} records"

    case model_type.downcase
    when "contact"
      process_contact_bulk_operation(operation_type, record_ids, options)
    when "campaign"
      process_campaign_bulk_operation(operation_type, record_ids, options)
    when "automation"
      process_automation_bulk_operation(operation_type, record_ids, options)
    when "template"
      process_template_bulk_operation(operation_type, record_ids, options)
    else
      raise ArgumentError, "Unsupported model type: #{model_type}"
    end

    Rails.logger.info "Completed bulk operation: #{operation_type} on #{model_type}"
  end

  private

  def process_contact_bulk_operation(operation_type, contact_ids, options)
    contacts = Contact.where(id: contact_ids)
    account = contacts.first&.account

    case operation_type
    when "delete"
      bulk_delete_contacts(contacts, options)
    when "unsubscribe"
      bulk_unsubscribe_contacts(contacts, options)
    when "resubscribe"
      bulk_resubscribe_contacts(contacts, options)
    when "add_tags"
      bulk_add_tags_to_contacts(contacts, options[:tags], options)
    when "remove_tags"
      bulk_remove_tags_from_contacts(contacts, options[:tags], options)
    when "update_field"
      bulk_update_contact_field(contacts, options[:field_name], options[:field_value], options)
    when "enrich"
      bulk_enrich_contacts(contacts, options)
    when "export"
      bulk_export_contacts(contacts, options)
    when "segment"
      bulk_segment_contacts(contacts, options)
    else
      raise ArgumentError, "Unsupported contact operation: #{operation_type}"
    end
  end

  def process_campaign_bulk_operation(operation_type, campaign_ids, options)
    campaigns = Campaign.where(id: campaign_ids)

    case operation_type
    when "delete"
      bulk_delete_campaigns(campaigns, options)
    when "duplicate"
      bulk_duplicate_campaigns(campaigns, options)
    when "pause"
      bulk_pause_campaigns(campaigns, options)
    when "resume"
      bulk_resume_campaigns(campaigns, options)
    when "schedule"
      bulk_schedule_campaigns(campaigns, options[:scheduled_at], options)
    when "add_tags"
      bulk_add_tags_to_campaigns(campaigns, options[:tags], options)
    else
      raise ArgumentError, "Unsupported campaign operation: #{operation_type}"
    end
  end

  def process_automation_bulk_operation(operation_type, automation_ids, options)
    automations = EmailAutomation.where(id: automation_ids)

    case operation_type
    when "activate"
      bulk_activate_automations(automations, options)
    when "deactivate"
      bulk_deactivate_automations(automations, options)
    when "duplicate"
      bulk_duplicate_automations(automations, options)
    when "delete"
      bulk_delete_automations(automations, options)
    else
      raise ArgumentError, "Unsupported automation operation: #{operation_type}"
    end
  end

  def process_template_bulk_operation(operation_type, template_ids, options)
    templates = Template.where(id: template_ids)

    case operation_type
    when "delete"
      bulk_delete_templates(templates, options)
    when "duplicate"
      bulk_duplicate_templates(templates, options)
    when "categorize"
      bulk_categorize_templates(templates, options[:category], options)
    else
      raise ArgumentError, "Unsupported template operation: #{operation_type}"
    end
  end

  # Contact bulk operations

  def bulk_delete_contacts(contacts, options)
    deleted_count = 0

    contacts.find_each do |contact|
      # Remove from active automations first
      contact.automation_enrollments.active.each do |enrollment|
        enrollment.update!(status: "cancelled", cancelled_at: Time.current)
      end

      # Log deletion
      ContactActivityLog.create!(
        contact: contact,
        account: contact.account,
        activity_type: "bulk_deleted",
        metadata: { deleted_by: options[:user_id] }
      )

      contact.destroy!
      deleted_count += 1
    end

    Rails.logger.info "Bulk deleted #{deleted_count} contacts"
  end

  def bulk_unsubscribe_contacts(contacts, options)
    unsubscribed_count = contacts.where(status: "subscribed")
                                .update_all(
                                  status: "unsubscribed",
                                  unsubscribed_at: Time.current
                                )

    # Log activity for each contact
    contacts.where(status: "unsubscribed").find_each do |contact|
      ContactActivityLog.create!(
        contact: contact,
        account: contact.account,
        activity_type: "bulk_unsubscribed",
        metadata: { unsubscribed_by: options[:user_id] }
      )
    end

    Rails.logger.info "Bulk unsubscribed #{unsubscribed_count} contacts"
  end

  def bulk_resubscribe_contacts(contacts, options)
    resubscribed_count = contacts.where(status: "unsubscribed")
                               .update_all(
                                 status: "subscribed",
                                 resubscribed_at: Time.current,
                                 unsubscribed_at: nil
                               )

    # Log activity for each contact
    contacts.where(status: "subscribed").find_each do |contact|
      ContactActivityLog.create!(
        contact: contact,
        account: contact.account,
        activity_type: "bulk_resubscribed",
        metadata: { resubscribed_by: options[:user_id] }
      )
    end

    Rails.logger.info "Bulk resubscribed #{resubscribed_count} contacts"
  end

  def bulk_add_tags_to_contacts(contacts, tag_names, options)
    return unless tag_names&.any?

    account = contacts.first.account
    tags = tag_names.map { |name| account.tags.find_or_create_by(name: name.strip) }

    contacts.find_each do |contact|
      tags.each do |tag|
        unless contact.tags.include?(tag)
          contact.tags << tag
        end
      end

      ContactActivityLog.create!(
        contact: contact,
        account: contact.account,
        activity_type: "bulk_tags_added",
        metadata: {
          tags: tag_names,
          added_by: options[:user_id]
        }
      )
    end

    Rails.logger.info "Added tags #{tag_names.join(', ')} to #{contacts.count} contacts"
  end

  def bulk_remove_tags_from_contacts(contacts, tag_names, options)
    return unless tag_names&.any?

    contacts.find_each do |contact|
      tags_to_remove = contact.tags.where(name: tag_names)
      contact.tags.delete(tags_to_remove)

      if tags_to_remove.any?
        ContactActivityLog.create!(
          contact: contact,
          account: contact.account,
          activity_type: "bulk_tags_removed",
          metadata: {
            tags: tags_to_remove.pluck(:name),
            removed_by: options[:user_id]
          }
        )
      end
    end

    Rails.logger.info "Removed tags #{tag_names.join(', ')} from contacts"
  end

  def bulk_update_contact_field(contacts, field_name, field_value, options)
    updated_count = 0

    contacts.find_each do |contact|
      if contact.respond_to?("#{field_name}=")
        old_value = contact.send(field_name)
        contact.update!(field_name => field_value)

        ContactActivityLog.create!(
          contact: contact,
          account: contact.account,
          activity_type: "bulk_field_updated",
          metadata: {
            field_name: field_name,
            old_value: old_value,
            new_value: field_value,
            updated_by: options[:user_id]
          }
        )

        updated_count += 1
      end
    end

    Rails.logger.info "Updated field #{field_name} for #{updated_count} contacts"
  end

  def bulk_enrich_contacts(contacts, options)
    enrichment_type = options[:enrichment_type] || "full"

    contacts.find_each do |contact|
      # Enqueue enrichment job for each contact
      ContactEnrichmentJob.perform_later(contact.id, enrichment_type)
    end

    Rails.logger.info "Queued enrichment for #{contacts.count} contacts"
  end

  def bulk_export_contacts(contacts, options)
    format = options[:format] || "csv"
    include_fields = options[:include_fields] || %w[email first_name last_name company status created_at]

    case format.downcase
    when "csv"
      export_contacts_to_csv(contacts, include_fields, options)
    when "xlsx"
      export_contacts_to_xlsx(contacts, include_fields, options)
    else
      raise ArgumentError, "Unsupported export format: #{format}"
    end
  end

  def bulk_segment_contacts(contacts, options)
    segment_name = options[:segment_name]
    segment_criteria = options[:segment_criteria]

    # Create a new tag for the segment
    account = contacts.first.account
    segment_tag = account.tags.find_or_create_by(name: "Segment: #{segment_name}")

    contacts.find_each do |contact|
      contact.tags << segment_tag unless contact.tags.include?(segment_tag)
    end

    Rails.logger.info "Created segment '#{segment_name}' with #{contacts.count} contacts"
  end

  # Campaign bulk operations

  def bulk_delete_campaigns(campaigns, options)
    deleted_count = 0

    campaigns.find_each do |campaign|
      # Only delete draft campaigns
      if campaign.draft?
        campaign.destroy!
        deleted_count += 1
      end
    end

    Rails.logger.info "Bulk deleted #{deleted_count} campaigns"
  end

  def bulk_duplicate_campaigns(campaigns, options)
    duplicated_count = 0

    campaigns.find_each do |campaign|
      duplicated_campaign = campaign.dup
      duplicated_campaign.name = "Copy of #{campaign.name}"
      duplicated_campaign.status = "draft"
      duplicated_campaign.sent_at = nil
      duplicated_campaign.scheduled_at = nil

      if duplicated_campaign.save
        # Copy tags
        campaign.tags.each do |tag|
          duplicated_campaign.tags << tag
        end

        duplicated_count += 1
      end
    end

    Rails.logger.info "Duplicated #{duplicated_count} campaigns"
  end

  def bulk_pause_campaigns(campaigns, options)
    paused_count = campaigns.where(status: "scheduled")
                           .update_all(status: "paused")

    Rails.logger.info "Paused #{paused_count} campaigns"
  end

  def bulk_resume_campaigns(campaigns, options)
    resumed_count = campaigns.where(status: "paused")
                            .update_all(status: "scheduled")

    Rails.logger.info "Resumed #{resumed_count} campaigns"
  end

  def bulk_schedule_campaigns(campaigns, scheduled_at, options)
    scheduled_count = campaigns.where(status: "draft")
                              .update_all(
                                status: "scheduled",
                                scheduled_at: scheduled_at
                              )

    Rails.logger.info "Scheduled #{scheduled_count} campaigns for #{scheduled_at}"
  end

  def bulk_add_tags_to_campaigns(campaigns, tag_names, options)
    return unless tag_names&.any?

    account = campaigns.first.account
    tags = tag_names.map { |name| account.tags.find_or_create_by(name: name.strip) }

    campaigns.find_each do |campaign|
      tags.each do |tag|
        unless campaign.tags.include?(tag)
          campaign.tags << tag
        end
      end
    end

    Rails.logger.info "Added tags to #{campaigns.count} campaigns"
  end

  # Automation bulk operations

  def bulk_activate_automations(automations, options)
    activated_count = automations.where(active: false)
                                .update_all(active: true)

    Rails.logger.info "Activated #{activated_count} automations"
  end

  def bulk_deactivate_automations(automations, options)
    deactivated_count = automations.where(active: true)
                                  .update_all(active: false)

    Rails.logger.info "Deactivated #{deactivated_count} automations"
  end

  def bulk_duplicate_automations(automations, options)
    duplicated_count = 0

    automations.find_each do |automation|
      duplicated_automation = automation.dup
      duplicated_automation.name = "Copy of #{automation.name}"
      duplicated_automation.active = false

      if duplicated_automation.save
        # Duplicate automation steps
        automation.automation_steps.order(:step_order).each do |step|
          duplicated_step = step.dup
          duplicated_step.email_automation = duplicated_automation
          duplicated_step.save!
        end

        duplicated_count += 1
      end
    end

    Rails.logger.info "Duplicated #{duplicated_count} automations"
  end

  def bulk_delete_automations(automations, options)
    deleted_count = 0

    automations.find_each do |automation|
      # Deactivate first
      automation.update!(active: false)

      # Cancel active enrollments
      automation.automation_enrollments.active.update_all(
        status: "cancelled",
        cancelled_at: Time.current
      )

      automation.destroy!
      deleted_count += 1
    end

    Rails.logger.info "Deleted #{deleted_count} automations"
  end

  # Template bulk operations

  def bulk_delete_templates(templates, options)
    deleted_count = templates.destroy_all
    Rails.logger.info "Bulk deleted #{deleted_count} templates"
  end

  def bulk_duplicate_templates(templates, options)
    duplicated_count = 0

    templates.find_each do |template|
      duplicated_template = template.dup
      duplicated_template.name = "Copy of #{template.name}"

      if duplicated_template.save
        duplicated_count += 1
      end
    end

    Rails.logger.info "Duplicated #{duplicated_count} templates"
  end

  def bulk_categorize_templates(templates, category, options)
    updated_count = templates.update_all(category: category)
    Rails.logger.info "Categorized #{updated_count} templates as '#{category}'"
  end

  # Export helpers

  def export_contacts_to_csv(contacts, include_fields, options)
    require "csv"

    file_path = Rails.root.join("tmp", "contacts_export_#{Time.current.to_i}.csv")

    CSV.open(file_path, "w", write_headers: true, headers: include_fields) do |csv|
      contacts.find_each do |contact|
        row_data = include_fields.map do |field|
          contact.respond_to?(field) ? contact.send(field) : contact.custom_fields&.dig(field)
        end
        csv << row_data
      end
    end

    Rails.logger.info "Exported #{contacts.count} contacts to CSV: #{file_path}"

    # Optionally upload to cloud storage or email to user
    if options[:email_to]
      ExportMailer.send_export_file(options[:email_to], file_path).deliver_now
    end
  end

  def export_contacts_to_xlsx(contacts, include_fields, options)
    # This would require the 'caxlsx' gem
    # Implementation would be similar to CSV but using Excel format
    Rails.logger.info "XLSX export would be implemented with caxlsx gem"
  end
end
