# A family adding money to its Scout Account by card through Stripe Checkout. It's created pending,
# then completed (crediting the Scout Account) when Stripe confirms payment, by webhook or when the
# family returns from Checkout, whichever comes first. Completing is idempotent.
#
# The pack can pass card fees on to families: ONLINE_PAYMENT_FEE_PERCENT (e.g. 2.9) and
# ONLINE_PAYMENT_FEE_CENTS (e.g. 30) add a fee so the pack still receives the full deposit. Both
# default to 0, in which case the pack absorbs Stripe's fee.
class OnlinePayment < ApplicationRecord
  include CentsAttribute

  MIN_CENTS = 500       # $5
  MAX_CENTS = 100_000   # $1,000

  class_attribute :gateway, default: StripeGateway.new

  belongs_to :family

  enum :status, { pending: 0, completed: 1, expired: 2 }, validate: true

  cents_attribute :amount, max_cents: MAX_CENTS

  validate :amount_in_range

  before_save :set_fee, if: :amount_cents_changed?

  def self.enabled?
    gateway.configured?
  end

  def self.fee_percent
    ENV.fetch("ONLINE_PAYMENT_FEE_PERCENT", "0").to_d
  end

  def self.fee_fixed_cents
    ENV.fetch("ONLINE_PAYMENT_FEE_CENTS", "0").to_i
  end

  def self.fee_for(cents)
    return 0 if fee_percent.zero? && fee_fixed_cents.zero?

    # Gross up so that after Stripe takes percent + fixed of the total, the deposit is left.
    total = ((cents + fee_fixed_cents) / (1 - (fee_percent / 100))).ceil
    total - cents
  end

  def total_cents
    amount_cents.to_i + fee_cents.to_i
  end

  def total
    Money.new(total_cents)
  end

  def fee
    Money.new(fee_cents.to_i)
  end

  # Credits the Scout Account once, however many times Stripe (or the return page) confirms it.
  # Returns true if this call credited it.
  def complete!(payment_intent_id: nil)
    credited = false
    DoubleEntry.lock_accounts(Ledger.external, family.ledger_account) do
      reload
      next unless pending?

      DoubleEntry.transfer(Money.new(amount_cents), from: Ledger.external, to: family.ledger_account, code: :deposit,
                           detail: self, metadata: { memo: "Online payment (card)", online_payment_id: id })
      update!(status: :completed, completed_at: Time.current, stripe_payment_intent_id: payment_intent_id)
      credited = true
    end
    credited
  end

  private

  def set_fee
    self.fee_cents = self.class.fee_for(amount_cents.to_i)
  end

  def amount_in_range
    return if errors.include?(:amount_dollars)
    return errors.add(:amount_dollars, "can't be blank") if amount_cents.nil?

    unless amount_cents.between?(MIN_CENTS, MAX_CENTS)
      errors.add(:amount_dollars, "must be between #{Money.new(MIN_CENTS).format} and #{Money.new(MAX_CENTS).format(no_cents_if_whole: true)}")
    end
  end
end
