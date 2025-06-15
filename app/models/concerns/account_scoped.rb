# frozen_string_literal: true

# Concern for models that belong to an account (multi-tenant functionality)
module AccountScoped
  extend ActiveSupport::Concern

  included do
    belongs_to :account, optional: false

    validates :account, presence: true

    scope :for_account, ->(account) { where(account: account) }

    before_validation :set_account_from_current, if: -> { account.blank? && Current.account.present? }
  end

  class_methods do
    def within_account(account)
      return none unless account

      where(account: account)
    end

    def count_by_account
      group(:account_id).count
    end

    def for_current_account
      return none unless Current.account

      where(account: Current.account)
    end
  end

  # Check if record belongs to the specified account
  def belongs_to_account?(check_account)
    account == check_account
  end

  # Ensure the record belongs to the current account
  def ensure_current_account!
    return true if Current.account.blank? # Skip check if no current account

    unless belongs_to_account?(Current.account)
      raise SecurityError, "Record does not belong to current account"
    end

    true
  end

  private

  def set_account_from_current
    self.account = Current.account
  end
end
