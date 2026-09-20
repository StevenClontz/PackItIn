require "test_helper"

class EventPaymentTest < ActiveSupport::TestCase
  def trip
    events(:weekend_trip)
  end

  def answer(person, status, option = nil)
    Rsvp.create!(event: trip, person: person, status: status, rsvp_option: option)
  end

  def payment_for(family = families(:one))
    EventPayment.new(event: trip, family: family)
  end

  # Sam takes the $60 weekend, Lily the $25 day trip.
  def everyone_attends
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "attending", rsvp_options(:day_trip)
  end

  # --- what is owed ---

  test "each attending person is charged their option's cost" do
    everyone_attends
    payment = payment_for

    assert_equal [ "Sam Smith", "Lily Smith" ].sort, payment.line_items.map { |item| item.person.full_name }.sort
    assert_equal Money.new(85_00), payment.total
    assert_equal Money.new(85_00), payment.outstanding
  end

  test "only attending people are charged" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "not_attending"
    assert_equal Money.new(60_00), payment_for.total

    Rsvp.find_by!(person: people(:smith_lion), event: trip).update!(status: "maybe", rsvp_option: rsvp_options(:day_trip))
    assert_equal Money.new(60_00), payment_for.total, "maybe isn't charged"
  end

  test "free options and events without options cost nothing" do
    free = RsvpOption.create!(event: trip, name: "Just visiting")
    answer people(:smith_dad), "attending", free
    assert_empty payment_for.line_items
    assert_equal Money.new(0), payment_for.total

    other = EventPayment.new(event: events(:pack_meeting), family: families(:one))
    assert_equal Money.new(0), other.total, "pack meeting has no options"
  end

  test "an option with a zero cost is free" do
    rsvp_options(:day_trip).update!(cost_cents: 0)
    answer people(:smith_dad), "attending", rsvp_options(:day_trip)
    assert_empty payment_for.line_items
  end

  test "a family is only charged for its own people" do
    everyone_attends
    joneses = payment_for(families(:two))
    assert_equal [ "Ben Jones" ], joneses.line_items.map { |item| item.person.full_name }
    assert_equal Money.new(25_00), joneses.total
  end

  # --- blockers ---

  test "everyone must be marked attending or not attending" do
    assert_equal [ "Lily Smith (no response)", "Sam Smith (no response)" ], payment_for.blockers

    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "maybe", rsvp_options(:day_trip)
    assert_equal [ "Lily Smith (maybe)" ], payment_for.blockers
    assert_not payment_for.payable?

    Rsvp.find_by!(person: people(:smith_lion), event: trip).update!(status: "not_attending")
    assert_empty payment_for.blockers
    assert payment_for.payable?
  end

  # --- what has been paid ---

  test "paid is the net of every ledger line between the family and the event" do
    assert_equal Money.new(0), payment_for.paid

    transact from: families(:one), to: trip, dollars: 30
    assert_equal Money.new(30_00), payment_for.paid

    transact from: trip, to: families(:one), dollars: 10, memo: "refund"
    assert_equal Money.new(20_00), payment_for.paid

    transact from: :outside, to: families(:one), dollars: 500
    transact from: :outside, to: trip, dollars: 500
    transact from: families(:two), to: trip, dollars: 99
    assert_equal Money.new(20_00), payment_for.paid, "deposits and other families' payments don't count"
  end

  test "outstanding is the cost less what has been paid" do
    everyone_attends
    transact from: families(:one), to: trip, dollars: 30
    assert_equal Money.new(55_00), payment_for.outstanding
  end

  test "relevant only when there is a cost or a payment" do
    assert_not payment_for.relevant?

    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    assert payment_for.relevant?

    Rsvp.find_by!(person: people(:smith_dad), event: trip).update!(status: "not_attending")
    assert_not payment_for.relevant?

    transact from: families(:one), to: trip, dollars: 5
    assert payment_for.relevant?, "a payment was made"
  end

  # --- paying ---

  test "paying moves exactly what is owed from the Scout Account to the event's account" do
    everyone_attends

    assert_difference "DoubleEntry::Line.count", 2 do
      assert_equal :paid, payment_for.pay(expected_cents: 85_00)
    end

    assert_equal Money.new(-85_00), families(:one).balance
    assert_equal Money.new(85_00), trip.balance
    line = families(:one).ledger_lines.first
    assert_equal :payment, line.code
    assert_equal trip, line.detail
    assert_equal "Payment for Weekend Trip RSVPs", line.metadata["memo"]
    assert_equal :payment, trip.ledger_lines.first.code

    assert_equal Money.new(85_00), payment_for.paid
    assert_equal Money.new(0), payment_for.outstanding
    assert_not payment_for.payable?
  end

  test "a second payment finds nothing due" do
    everyone_attends
    payment_for.pay(expected_cents: 85_00)

    assert_no_difference "DoubleEntry::Line.count" do
      assert_equal :nothing_due, payment_for.pay(expected_cents: 85_00)
    end
  end

  test "a payment for an amount that is no longer what is owed is refused" do
    everyone_attends

    assert_no_difference "DoubleEntry::Line.count" do
      assert_equal :amount_changed, payment_for.pay(expected_cents: 60_00)
      assert_equal :amount_changed, payment_for.pay(expected_cents: 0)
      assert_equal :amount_changed, payment_for.pay(expected_cents: nil)
    end
    assert_equal Money.new(0), families(:one).balance
  end

  test "payment is refused while anyone is unanswered or maybe" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "maybe", rsvp_options(:day_trip)

    assert_no_difference "DoubleEntry::Line.count" do
      assert_equal :not_ready, payment_for.pay(expected_cents: 60_00)
    end
  end

  test "paying with nothing owed does nothing" do
    answer people(:smith_dad), "not_attending"
    answer people(:smith_lion), "not_attending"

    assert_no_difference "DoubleEntry::Line.count" do
      assert_equal :nothing_due, payment_for.pay(expected_cents: 0)
    end
  end

  test "a family may pay more than its Scout Account holds" do
    everyone_attends
    transact from: :outside, to: families(:one), dollars: 10

    assert_equal :paid, payment_for.pay(expected_cents: 85_00)
    assert_equal Money.new(-75_00), families(:one).balance
  end

  test "changing an RSVP after paying changes only what is still owed" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "not_attending"
    payment_for.pay(expected_cents: 60_00)

    Rsvp.find_by!(person: people(:smith_lion), event: trip).update!(status: "attending", rsvp_option: rsvp_options(:day_trip))
    assert_equal Money.new(25_00), payment_for.outstanding
    assert_equal :paid, payment_for.pay(expected_cents: 25_00)
    assert_equal Money.new(85_00), payment_for.paid
    assert_equal Money.new(85_00), trip.balance
  end

  test "dropping out after paying leaves an overpayment that can't be paid" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "not_attending"
    payment_for.pay(expected_cents: 60_00)

    Rsvp.find_by!(person: people(:smith_dad), event: trip).update!(status: "not_attending")
    payment = payment_for
    assert payment.overpaid?
    assert_equal Money.new(-60_00), payment.outstanding
    assert_not payment.payable?
    assert_equal :nothing_due, payment.pay(expected_cents: 60_00)
  end

  test "an admin refund makes the amount owed again" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "not_attending"
    payment_for.pay(expected_cents: 60_00)

    transact from: trip, to: families(:one), dollars: 60, memo: "refund"
    assert_equal Money.new(0), payment_for.paid
    assert_equal Money.new(60_00), payment_for.outstanding
  end

  test "families pay independently" do
    everyone_attends

    assert_equal :paid, payment_for(families(:two)).pay(expected_cents: 25_00)
    assert_equal Money.new(0), payment_for.paid
    assert_equal Money.new(85_00), payment_for.outstanding
    assert_equal Money.new(-25_00), families(:two).balance
  end

  # --- youth pricing ---

  test "an adult and a non-adult pay their own price for the same option" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)   # adult: $60
    answer people(:smith_lion), "attending", rsvp_options(:full_weekend)  # lion: $30 youth price

    payment = payment_for
    assert_equal [ Money.new(30_00), Money.new(60_00) ], payment.line_items.map(&:cost).sort
    assert_equal Money.new(90_00), payment.total
  end

  test "paying charges the mixed total" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "attending", rsvp_options(:full_weekend)

    assert_equal :paid, payment_for.pay(expected_cents: 90_00)
    assert_equal Money.new(-90_00), families(:one).balance
    assert_equal Money.new(90_00), trip.balance
  end

  test "an option with one price charges an adult and a non-adult the same" do
    answer people(:smith_dad), "attending", rsvp_options(:day_trip)
    answer people(:smith_lion), "attending", rsvp_options(:day_trip)
    assert_equal [ Money.new(25_00), Money.new(25_00) ], payment_for.line_items.map(&:cost)
  end

  test "an option with only a youth price charges just the non-adults" do
    youth_only = RsvpOption.create!(event: trip, name: "Scouts only", youth_cost_dollars: "12")
    answer people(:smith_dad), "attending", youth_only
    answer people(:smith_lion), "attending", youth_only

    assert_equal [ "Lily Smith" ], payment_for.line_items.map { |item| item.person.full_name }
    assert_equal Money.new(12_00), payment_for.total
  end

  test "an option that is free for youth charges just the adults" do
    free_for_youth = RsvpOption.create!(event: trip, name: "Family pass", cost_dollars: "20", youth_cost_dollars: "0")
    answer people(:smith_dad), "attending", free_for_youth
    answer people(:smith_lion), "attending", free_for_youth

    assert_equal [ "Sam Smith" ], payment_for.line_items.map { |item| item.person.full_name }
    assert_equal Money.new(20_00), payment_for.total
  end

  test "a family whose option is free for everyone has nothing to pay" do
    free = RsvpOption.create!(event: trip, name: "Just visiting", cost_dollars: "0", youth_cost_dollars: "0")
    answer people(:smith_dad), "attending", free
    answer people(:smith_lion), "attending", free

    assert_empty payment_for.line_items
    assert_not payment_for.relevant?
  end
end
