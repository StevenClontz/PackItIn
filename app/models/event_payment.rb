# What one family owes for the options its people chose at an event, and paying it from the family's
# Scout Account into the event's account.
#
# Only attending people whose option has a cost are charged. Paying is blocked until every person in the
# family is marked attending or not attending. What is owed is the total cost minus what the family has
# already paid this event: the net of every ledger line between the family's account and the event's
# (payments, refunds and corrections alike), so an RSVP change after paying just changes the next amount.
class EventPayment
  Item = Data.define(:person, :option, :cost)

  attr_reader :event, :family

  def initialize(event:, family:)
    @event = event
    @family = family
  end

  # The options the family's attending people chose that cost them something, at each person's own price.
  def line_items
    people.filter_map do |person|
      rsvp = rsvps[person.id]
      next unless rsvp&.attending? && rsvp.rsvp_option

      cost = rsvp.rsvp_option.cost_for(person)
      Item.new(person, rsvp.rsvp_option, cost) if cost.positive?
    end
  end

  def total
    line_items.sum(Money.new(0), &:cost)
  end

  # Net money this family has put into the event's account.
  def paid
    cents = family.ledger_lines.where(partner_account: "event", partner_scope: event.id.to_s).sum(:amount)
    Money.new(-cents)
  end

  def outstanding
    total - paid
  end

  # People who still need an answer of attending or not attending, e.g. "Sam Smith (maybe)".
  def blockers
    people.filter_map do |person|
      rsvp = rsvps[person.id]
      next if rsvp&.attending? || rsvp&.not_attending?

      "#{person.full_name} (#{rsvp ? rsvp.status_label.downcase : 'no response'})"
    end
  end

  # Whether there is anything to show: a cost to pay, or a payment already made.
  def relevant?
    line_items.any? || !paid.zero?
  end

  def payable?
    blockers.empty? && outstanding.positive?
  end

  def overpaid?
    outstanding.negative?
  end

  # Pays the outstanding amount, but only if it is still exactly `expected_cents` (what the family was
  # shown), so a stale page or a double click can't pay twice. Returns :paid, :not_ready, :nothing_due or
  # :amount_changed. Everything is recomputed with both accounts locked.
  def pay(expected_cents:)
    result = nil
    DoubleEntry.lock_accounts(family.ledger_account, event.ledger_account) do
      result = attempt_payment(expected_cents.to_i)
    end
    result
  end

  private

  def attempt_payment(expected_cents)
    return :not_ready if blockers.any?

    amount = outstanding
    return :nothing_due unless amount.positive?
    return :amount_changed unless amount.fractional == expected_cents

    DoubleEntry.transfer(amount, from: family.ledger_account, to: event.ledger_account, code: :payment,
                                 detail: event, metadata: { memo: "Payment for #{event.title} RSVPs" })
    :paid
  end

  def people
    @people ||= family.people.order(:last_name, :first_name).to_a
  end

  def rsvps
    @rsvps ||= event.rsvps.where(person_id: people.map(&:id)).includes(:rsvp_option).index_by(&:person_id)
  end
end
