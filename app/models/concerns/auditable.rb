# frozen_string_literal: true

# Concern for models that need audit logging functionality
module Auditable
  extend ActiveSupport::Concern

  included do
    has_many :audit_logs, -> { order(created_at: :desc) }, 
             as: :resource, dependent: :destroy
    
    after_create :log_creation
    after_update :log_update
    after_destroy :log_destruction

    scope :recently_created, -> { where('created_at >= ?', 24.hours.ago) }
    scope :recently_updated, -> { where('updated_at >= ?', 24.hours.ago) }
  end

  class_methods do
    def with_audit_logs
      includes(:audit_logs)
    end
  end

  private

  def log_creation
    create_audit_log('created', "#{self.class.name} '#{audit_display_name}' was created")
  end

  def log_update
    return unless saved_changes.present?
    
    changed_fields = saved_changes.keys - %w[updated_at]
    return if changed_fields.empty?
    
    details = changed_fields.map do |field|
      old_value = saved_changes[field][0]
      new_value = saved_changes[field][1]
      "#{field}: '#{old_value}' → '#{new_value}'"
    end.join(', ')
    
    create_audit_log('updated', "#{self.class.name} '#{audit_display_name}' was updated: #{details}")
  end

  def log_destruction
    create_audit_log('deleted', "#{self.class.name} '#{audit_display_name}' was deleted")
  end

  def create_audit_log(action, details)
    account = respond_to?(:account) ? self.account : nil
    
    audit_logs.create!(
      account: account,
      user: Current.user,
      action: action,
      details: details,
      ip_address: Current.ip_address,
      user_agent: Current.user_agent
    )
  rescue => e
    Rails.logger.warn "Failed to create audit log: #{e.message}"
  end

  def audit_display_name
    if respond_to?(:name) && name.present?
      name
    elsif respond_to?(:title) && title.present?
      title
    elsif respond_to?(:email) && email.present?
      email
    else
      id.to_s
    end
  end
end
