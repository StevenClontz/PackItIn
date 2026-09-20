# One way to attend an event ("Day trip only", "Full weekend"), defined per event by an admin.
class RsvpOption < ApplicationRecord
  MAX_COST_CENTS = 10_000_000 # $100,000 per person

  belongs_to :event
  # Responses keep their answer when an option is deleted; they just lose the choice and need a new one.
  has_many :rsvps, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
  validate :cost_is_a_dollar_amount, :cost_is_in_range

  # The cost per person as Money, or nil when the option has no cost.
  def cost
    Money.new(cost_cents) if cost_cents
  end

  def costed?
    cost_cents.to_i.positive?
  end

  # "Full weekend ($60.00)" for a costed option, else just the name.
  def label
    costed? ? "#{name} (#{cost.format})" : name
  end

  # The cost as typed in the form ("25", "25.50"). Keeps what was entered so a rejected form shows it again.
  def cost_dollars
    @cost_dollars_input || (cost_cents && format("%d.%02d", *cost_cents.divmod(100)))
  end

  def cost_dollars=(input)
    @cost_dollars_input = input
    self.cost_cents = Ledger.parse_dollars(input)&.fractional
  end

  private

  def cost_is_a_dollar_amount
    return if @cost_dollars_input.blank? || Ledger.parse_dollars(@cost_dollars_input)

    errors.add(:cost_dollars, "must be a dollar amount such as 25 or 25.50")
  end

  def cost_is_in_range
    return if cost_cents.nil? || cost_cents.between?(0, MAX_COST_CENTS)

    errors.add(:cost_dollars, "must be between $0 and $100,000")
  end
end
