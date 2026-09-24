require "test_helper"

class EventPaymentsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  def trip
    events(:weekend_trip)
  end

  def answer(person, status, option = nil)
    Rsvp.create!(event: trip, person: person, status: status, rsvp_option: option)
  end

  # Sam takes the $60 weekend; Lily isn't going.
  def sam_attends
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "not_attending"
  end

  def pay(amount_cents, **extra)
    post event_payment_path(trip), params: { amount_cents: amount_cents, **extra }
  end

  # --- guests ---

  test "guests are sent to sign in and can't pay" do
    assert_no_difference "DoubleEntry::Line.count" do
      pay 6000
    end
    assert_redirected_to new_family_session_path
  end

  # --- the Costs panel ---

  test "a family with costed attending RSVPs sees what it owes and a Pay button" do
    sam_attends
    transact from: :outside, to: families(:one), dollars: 100
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_response :success
    assert_select "h3", "Costs"
    assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*- Full weekend\s*\$60\.00/
    assert_select "dd", text: "$60.00", minimum: 2 # total and still to pay
    assert_select "dd", text: "$0.00", count: 1 # already paid
    assert_select "p", text: /Our Scout Account balance is \$100\.00\./
    assert_select "strong", text: /This will leave/, count: 0
    assert_select "form[action=?][method=post]", event_payment_path(trip) do
      assert_select "input[name=amount_cents][value=?]", "6000"
      assert_select "button", "Pay $60.00 from our Scout Account"
    end
  end

  test "the panel warns before a payment would take the Scout Account negative" do
    sam_attends
    transact from: :outside, to: families(:one), dollars: 20
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_select "p", text: /Our Scout Account balance is \$20\.00\./
    assert_select "strong", text: "This will leave our Scout Account at -$40.00."
    assert_select "button", "Pay $60.00 from our Scout Account"
  end

  test "the panel is hidden when the family owes nothing and has paid nothing" do
    answer people(:smith_dad), "not_attending"
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_select "h3", text: "Costs", count: 0

    get event_path(events(:pack_meeting))
    assert_select "h3", text: "Costs", count: 0
  end

  test "the panel is hidden until a costed option has been chosen" do
    sign_in_as "examplefamily"
    get event_path(trip)
    assert_select "h3", text: "Costs", count: 0
  end

  test "someone still marked maybe, or unanswered, blocks payment and is named" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "maybe", rsvp_options(:day_trip)
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_match "Before paying, mark everyone as attending or not attending", response.body
    assert_select "li", text: /Lily Smith\s*Lion\s*\(maybe\)/
    assert_select "button", text: /Pay/, count: 0

    assert_no_difference "DoubleEntry::Line.count" do
      pay 6000
    end
    assert_redirected_to event_path(trip)
    follow_redirect!
    assert_match "Mark everyone attending or not attending before paying.", response.body
  end

  test "an unanswered person is listed as no response" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_select "li", text: /Lily Smith\s*Lion\s*\(no response\)/
    assert_select "button", text: /Pay/, count: 0
  end

  # --- paying ---

  test "a family pays from its Scout Account into the event's account" do
    sam_attends
    sign_in_as "examplefamily"

    assert_difference "DoubleEntry::Line.count", 2 do
      pay 6000
    end
    assert_redirected_to event_path(trip)
    assert_response :see_other
    follow_redirect!
    assert_match "Paid $60.00 for Weekend Trip.", response.body

    assert_equal Money.new(-60_00), families(:one).balance
    assert_equal Money.new(60_00), trip.balance
    assert_select "p", text: "Paid in full."
    assert_select "button", text: /Pay/, count: 0
    assert_select "dd", text: "$60.00", minimum: 1
  end

  test "the payment shows on the family's statement and on the event's account" do
    sam_attends
    sign_in_as "examplefamily"
    pay 6000

    get family_account_path(families(:one))
    assert_select "td", text: /Payment to Weekend Trip\s*Payment for Weekend Trip RSVPs/
    assert_select "span.text-red-600", text: "-$60.00", minimum: 1

    get event_path(trip)
    assert_select "a[href=?]", event_account_path(trip), count: 0 # event accounts are admin-only
    assert_select "td", text: /Payment from/, count: 0 # the event page doesn't list transactions

    delete destroy_family_session_path
    sign_in_as "adminfamily"

    get event_account_path(trip)
    assert_select "h2", "Weekend Trip Event Account"
    assert_select "p", text: /Balance:\s*\$60\.00/
    assert_select "td", text: /Payment from The Example Family/
  end

  test "an admin can see the event's account, with the families that paid" do
    sam_attends
    sign_in_as "examplefamily"
    pay 6000
    delete destroy_family_session_path
    sign_in_as "adminfamily"

    get event_account_path(trip)
    assert_select "p", text: /Balance:\s*\$60\.00/
    assert_select "td", text: /Payment from The Example Family/
  end

  test "a payment is refused if the amount it was shown is no longer what is owed" do
    sam_attends
    sign_in_as "examplefamily"

    assert_no_difference "DoubleEntry::Line.count" do
      pay 100
    end
    assert_redirected_to event_path(trip)
    follow_redirect!
    assert_match "The amount due changed. Please review it and try again.", response.body
    assert_equal Money.new(0), families(:one).balance
  end

  test "paying twice only pays once" do
    sam_attends
    sign_in_as "examplefamily"

    pay 6000
    assert_no_difference "DoubleEntry::Line.count" do
      pay 6000
    end
    follow_redirect!
    assert_match "There is nothing to pay for Weekend Trip.", response.body
    assert_equal Money.new(-60_00), families(:one).balance
  end

  test "only the signed-in family is ever charged" do
    sam_attends
    sign_in_as "examplefamily"

    pay 6000, family_id: families(:two).id, family: { id: families(:two).id }
    assert_equal Money.new(0), families(:two).balance, "Ben's family wasn't charged"
    assert_equal Money.new(-60_00), families(:one).balance

    assert_equal Money.new(25_00), EventPayment.new(event: trip, family: families(:two)).outstanding, "and still owes its own $25"
  end

  test "a family pays only for its own people's options" do
    sam_attends
    sign_in_as "joneses"

    get event_path(trip)
    assert_select "li", text: /Ben Jones\s*Bear\s*- Day trip only\s*\$25\.00/
    assert_select "li", text: /Sam Smith/, count: 0

    pay 2500
    assert_equal Money.new(25_00), trip.balance
    assert_equal Money.new(0), families(:one).balance
  end

  test "an event that doesn't exist is a 404" do
    sign_in_as "examplefamily"
    post event_payment_path(event_id: 0), params: { amount_cents: 100 }
    assert_response :not_found
  end

  # --- after paying ---

  test "changing an RSVP after paying asks for only the difference" do
    sam_attends
    sign_in_as "examplefamily"
    pay 6000

    Rsvp.find_by!(person: people(:smith_lion), event: trip).update!(status: "attending", rsvp_option: rsvp_options(:day_trip))
    get event_path(trip)
    assert_select "button", "Pay $25.00 from our Scout Account"
    assert_select "dd", text: "$85.00"

    pay 2500
    assert_equal Money.new(85_00), trip.balance
  end

  test "dropping out after paying says the payment is too much and offers no button" do
    sam_attends
    sign_in_as "examplefamily"
    pay 6000
    Rsvp.find_by!(person: people(:smith_dad), event: trip).update!(status: "not_attending")

    get event_path(trip)
    assert_select "p", text: /We have paid \$60\.00 more than the current cost\. Ask a pack administrator about a refund\./
    assert_select "button", text: /Pay/, count: 0
  end

  test "an admin refund makes the amount payable again" do
    sam_attends
    sign_in_as "examplefamily"
    pay 6000
    transact from: trip, to: families(:one), dollars: 60, memo: "refund"

    get event_path(trip)
    assert_select "button", "Pay $60.00 from our Scout Account"
  end

  test "payment is allowed after the RSVP deadline" do
    sam_attends
    sign_in_as "examplefamily"

    travel_to trip.ends_at + 1.day do
      pay 6000
      assert_redirected_to event_path(trip)
    end
    assert_equal Money.new(60_00), trip.balance
  end

  # --- youth pricing ---

  test "the Costs panel shows each person's own price and pays the mixed total" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "attending", rsvp_options(:full_weekend)
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*- Full weekend\s*\$60\.00/
    assert_select "li", text: /Lily Smith\s*Lion\s*- Full weekend\s*\$30\.00/
    assert_select "button", "Pay $90.00 from our Scout Account"

    pay 9000
    assert_equal Money.new(-90_00), families(:one).balance
    assert_equal Money.new(90_00), trip.balance
  end

  # --- den badges ---

  test "the Costs line items show each person's den" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    answer people(:smith_lion), "attending", rsvp_options(:full_weekend)
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_select "li span.rounded-full", text: "Adult (Lion)", count: 1
    assert_select "li span.rounded-full", text: "Lion", count: 1
  end

  test "each person blocking payment is listed with their den" do
    answer people(:smith_dad), "attending", rsvp_options(:full_weekend)
    sign_in_as "examplefamily"

    get event_path(trip)
    assert_select "li", text: /Lily Smith\s*Lion\s*\(no response\)/ do
      assert_select "span.rounded-full", text: "Lion"
    end
  end
end
