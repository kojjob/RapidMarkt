class Subscription < ApplicationRecord
  # Associations
  belongs_to :account

  # Validations
  validates :plan_name, presence: true
  validates :status, inclusion: { in: %w[active past_due canceled unpaid trialing incomplete incomplete_expired] }
  validates :stripe_subscription_id, presence: true, uniqueness: true
  validates :stripe_customer_id, presence: true

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :trialing, -> { where(status: "trialing") }
  scope :past_due, -> { where(status: "past_due") }
  scope :canceled, -> { where(status: "canceled") }

  # Methods
  def active?
    status == "active"
  end

  def trialing?
    status == "trialing"
  end

  def past_due?
    status == "past_due"
  end

  def canceled?
    status == "canceled"
  end

  def on_trial?
    trial_end.present? && trial_end > Time.current
  end

  def trial_days_remaining
    return 0 unless on_trial?

    ((trial_end - Time.current) / 1.day).ceil
  end

  def current_period_days_remaining
    return 0 unless current_period_end.present?

    days = ((current_period_end - Time.current) / 1.day).ceil
    [ days, 0 ].max
  end

  def sync_with_stripe!
    return unless stripe_subscription_id.present?

    stripe_subscription = Stripe::Subscription.retrieve(stripe_subscription_id)

    update!(
      status: stripe_subscription.status,
      current_period_start: Time.at(stripe_subscription.current_period_start),
      current_period_end: Time.at(stripe_subscription.current_period_end),
      trial_end: stripe_subscription.trial_end ? Time.at(stripe_subscription.trial_end) : nil
    )
  rescue Stripe::StripeError => e
    Rails.logger.error "Failed to sync subscription #{id} with Stripe: #{e.message}"
    false
  end
end
