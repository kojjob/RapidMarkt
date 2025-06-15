# frozen_string_literal: true

# Job to process queued contact enrichment requests
class ProcessContactEnrichmentQueueJob < ApplicationJob
  include Auditable

  queue_as :enrichment

  retry_on StandardError, attempts: 2

  def perform
    Rails.logger.info "Processing contact enrichment queue at #{Time.current}"

    # Find contacts that need enrichment
    contacts_to_enrich = Contact.includes(:account)
                               .where(enrichment_status: [ "pending", nil ])
                               .where("last_enriched_at IS NULL OR last_enriched_at < ?", 30.days.ago)
                               .where(status: "subscribed")
                               .limit(100) # Process in batches

    Rails.logger.info "Found #{contacts_to_enrich.count} contacts to enrich"

    contacts_to_enrich.find_each do |contact|
      # Skip if account doesn't have enrichment enabled
      next unless contact.account.enrichment_enabled?

      # Update status to prevent double processing
      contact.update!(enrichment_status: "queued")

      # Enqueue enrichment job
      ContactEnrichmentJob.perform_later(contact.id, "full")

      Rails.logger.debug "Queued enrichment for contact #{contact.id}"
    end

    Rails.logger.info "Finished processing contact enrichment queue"
  end
end
