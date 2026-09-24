require "test_helper"

class RsvpsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  # responses: { person => "attending" } or { person => { status: "attending", rsvp_option_id: option.id } }
  def rsvp_to(event, responses)
    rsvps = responses.to_h { |person, answer| [ person.id.to_s, answer.is_a?(Hash) ? answer : { status: answer } ] }
    patch event_rsvp_path(event), params: { rsvps: rsvps }
  end

  def status_of(event, person)
    Rsvp.find_by(event: event, person: person)&.status
  end

  def assert_closed_alert
    assert_redirected_to event_path(@event_under_test)
    follow_redirect!
    assert_match "RSVPs for this event closed", response.body
  end

  # --- guests ---

  test "guests are sent to sign in" do
    assert_no_difference "Rsvp.count" do
      rsvp_to events(:campout), people(:smith_dad) => "attending"
    end
    assert_redirected_to new_family_session_path
  end

  # --- the form ---

  test "family sees a radio group for each of its people with current answers checked" do
    sign_in_as "examplefamily"

    get event_path(events(:pack_meeting))
    assert_response :success
    assert_select "form[action=?]", event_rsvp_path(events(:pack_meeting))
    [ people(:smith_dad), people(:smith_lion) ].each do |person|
      assert_select "input[type=radio][name=?]", "rsvps[#{person.id}][status]", count: 3
    end
    assert_select "input[type=radio][name=?][value=attending][checked]", "rsvps[#{people(:smith_dad).id}][status]"
    assert_select "input[type=radio][name=?][value=maybe][checked]", "rsvps[#{people(:smith_lion).id}][status]"
    assert_select "input[type=radio][checked]", count: 2

    assert_select "label", text: "Attending", minimum: 2
    assert_select "label", text: "Maybe", minimum: 2
    assert_select "label", text: "Not attending", minimum: 2
    assert_select "input[type=submit][value=?]", "Save RSVPs"
  end

  test "family only sees its own people and responses" do
    sign_in_as "examplefamily"

    get event_path(events(:pack_meeting))
    assert_no_match "Ben Jones", response.body
    assert_select "input[name^=?]", "rsvps[#{people(:jones_bear).id}]", count: 0
    assert_no_match "All responses", response.body
  end

  test "an unanswered event has no radios checked" do
    sign_in_as "examplefamily"

    get event_path(events(:campout))
    assert_select "input[type=radio]", count: 6
    assert_select "input[type=radio][checked]", count: 0
  end

  # --- saving ---

  test "family RSVPs its people" do
    sign_in_as "examplefamily"

    assert_difference "Rsvp.count", 2 do
      rsvp_to events(:campout), people(:smith_dad) => "attending", people(:smith_lion) => "not_attending"
    end
    assert_redirected_to event_path(events(:campout))
    assert_response :see_other
    follow_redirect!
    assert_match "RSVPs saved.", response.body

    assert_equal "attending", status_of(events(:campout), people(:smith_dad))
    assert_equal "not_attending", status_of(events(:campout), people(:smith_lion))
    assert_select "input[type=radio][name=?][value=not_attending][checked]", "rsvps[#{people(:smith_lion).id}][status]"
  end

  test "family changes an existing RSVP without creating a duplicate" do
    sign_in_as "examplefamily"

    assert_no_difference "Rsvp.count" do
      rsvp_to events(:pack_meeting), people(:smith_dad) => "maybe"
    end
    assert_equal "maybe", status_of(events(:pack_meeting), people(:smith_dad))
    assert_equal "maybe", status_of(events(:pack_meeting), people(:smith_lion)), "others are untouched"
  end

  test "submitting only some people leaves the rest alone" do
    sign_in_as "examplefamily"

    rsvp_to events(:pack_meeting), people(:smith_lion) => "attending"
    assert_equal "attending", status_of(events(:pack_meeting), people(:smith_lion))
    assert_equal "attending", status_of(events(:pack_meeting), people(:smith_dad))
  end

  # --- what a family can't do ---

  test "family cannot RSVP another family's person" do
    sign_in_as "examplefamily"

    assert_no_difference "Rsvp.count" do
      rsvp_to events(:campout), people(:jones_bear) => "attending"
      assert_denied
    end
    rsvp_to events(:pack_meeting), people(:jones_bear) => "attending"
    assert_denied
    assert_equal "not_attending", status_of(events(:pack_meeting), people(:jones_bear))
  end

  test "a submission that includes someone else's person saves nothing" do
    sign_in_as "examplefamily"

    assert_no_difference "Rsvp.count" do
      rsvp_to events(:campout), people(:smith_dad) => "attending", people(:jones_bear) => "attending"
      assert_denied
    end
    assert_nil status_of(events(:campout), people(:smith_dad))
  end

  test "an invalid status saves nothing, even alongside valid ones" do
    sign_in_as "examplefamily"

    assert_no_difference "Rsvp.count" do
      rsvp_to events(:campout), people(:smith_dad) => "attending", people(:smith_lion) => "definitely"
    end
    assert_redirected_to event_path(events(:campout))
    follow_redirect!
    assert_match "Nothing was saved.", response.body
    assert_nil status_of(events(:campout), people(:smith_dad))
  end

  test "an unknown person is a 404 and an empty submission is rejected gently" do
    sign_in_as "examplefamily"

    patch event_rsvp_path(events(:campout)), params: { rsvps: { "0" => { status: "attending" } } }
    assert_response :not_found

    patch event_rsvp_path(events(:campout)), params: { rsvps: { people(:smith_dad).id.to_s => "attending" } }
    assert_redirected_to event_path(events(:campout))
    follow_redirect!
    assert_match "That response isn&#39;t valid", response.body

    [ {}, { rsvps: "oops" }, { rsvps: {} } ].each do |params|
      patch event_rsvp_path(events(:campout)), params: params
      assert_redirected_to event_path(events(:campout))
      follow_redirect!
      assert_match "Choose a response", response.body
    end
    assert_equal 0, Rsvp.where(event: events(:campout)).count
  end

  # --- the deadline ---

  test "after the event ends (no explicit deadline) families are locked out but can still see their answers" do
    @event_under_test = events(:pack_meeting)
    sign_in_as "examplefamily"

    travel_to @event_under_test.ends_at + 1.minute do
      rsvp_to @event_under_test, people(:smith_dad) => "not_attending"
      assert_closed_alert
      assert_equal "attending", status_of(@event_under_test, people(:smith_dad))

      get event_path(@event_under_test)
      assert_select "form[action=?]", event_rsvp_path(@event_under_test), count: 0
      assert_select "input[type=radio]", count: 0
      assert_match "RSVPs closed", response.body
      assert_match "Attending", response.body
      assert_match "Maybe", response.body
    end
  end

  test "read-only answers say No response where there is none" do
    sign_in_as "examplefamily"

    travel_to events(:campout).rsvp_deadline_at + 1.minute do
      get event_path(events(:campout))
      assert_select "form[action=?]", event_rsvp_path(events(:campout)), count: 0
      assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*No response/
    end
  end

  test "an explicit RSVP deadline closes RSVPs before the event starts" do
    @event_under_test = events(:campout)
    sign_in_as "examplefamily"
    deadline = @event_under_test.rsvp_deadline_at

    travel_to deadline - 1.minute do
      rsvp_to @event_under_test, people(:smith_dad) => "attending"
      assert_redirected_to event_path(@event_under_test)
      assert_equal "attending", status_of(@event_under_test, people(:smith_dad))
    end

    travel_to deadline + 1.minute do
      assert @event_under_test.starts_at.future?
      rsvp_to @event_under_test, people(:smith_dad) => "not_attending"
      assert_closed_alert
      assert_equal "attending", status_of(@event_under_test, people(:smith_dad))
    end
  end

  test "families cannot RSVP to a past event" do
    @event_under_test = events(:past_hike)
    sign_in_as "examplefamily"

    assert_no_difference "Rsvp.count" do
      rsvp_to @event_under_test, people(:smith_dad) => "attending"
    end
    assert_closed_alert
  end

  test "an admin can still change RSVPs for anyone after the deadline" do
    sign_in_as "adminfamily"

    travel_to events(:pack_meeting).ends_at + 1.minute do
      rsvp_to events(:pack_meeting), people(:jones_bear) => "attending", people(:smith_dad) => "maybe"
      assert_redirected_to event_path(events(:pack_meeting))
      follow_redirect!
      assert_match "RSVPs saved.", response.body
    end
    assert_equal "attending", status_of(events(:pack_meeting), people(:jones_bear))
    assert_equal "maybe", status_of(events(:pack_meeting), people(:smith_dad))
  end

  # --- admin view ---

  test "admin sees everyone's responses grouped by status" do
    sign_in_as "adminfamily"

    get event_path(events(:pack_meeting))
    assert_response :success
    assert_match "All responses", response.body
    assert_select "p", text: /Attending \(1\)/
    assert_select "p", text: /Maybe \(1\)/
    assert_select "p", text: /Not attending \(1\)/
    assert_select "p", text: /No response \(#{Person.count - 3}\)/
    assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*\(The Example Family\)/
    assert_select "li", text: /Ben Jones\s*Bear\s*\(The Joneses\)/

    get event_path(events(:campout))
    assert_select "p", text: /No response \(#{Person.count}\)/
    assert_select "p", text: /Attending \(0\)/
  end

  test "an admin with people of their own still gets the form after the deadline, with a note" do
    families(:admin).people.create!(first_name: "Ada", last_name: "Admin", den: :adult)
    sign_in_as "adminfamily"

    travel_to events(:pack_meeting).ends_at + 1.minute do
      get event_path(events(:pack_meeting))
      assert_select "form[action=?]", event_rsvp_path(events(:pack_meeting))
      assert_match "closed to families", response.body
    end
  end

  test "admin whose family has no people sees a note instead of the form" do
    sign_in_as "adminfamily"

    get event_path(events(:pack_meeting))
    assert_match "Your family has no people yet", response.body
    assert_select "input[type=radio]", count: 0
  end

  # --- options ---

  def option_answer(status, option)
    { status: status, rsvp_option_id: option&.id }
  end

  test "the form has an option select per person only on events that have options" do
    sign_in_as "examplefamily"

    get event_path(events(:weekend_trip))
    { people(:smith_dad) => "$60.00", people(:smith_lion) => "$30.00" }.each do |person, weekend_price|
      assert_select "select[name=?]", "rsvps[#{person.id}][rsvp_option_id]" do
        assert_select "option", text: "Choose an option"
        assert_select "option", text: "Day trip only ($25.00)"
        assert_select "option", text: "Full weekend (#{weekend_price})"
      end
    end

    get event_path(events(:pack_meeting))
    assert_select "select", count: 0
  end

  test "the form pre-selects the current answer and option" do
    Rsvp.create!(event: events(:weekend_trip), person: people(:smith_dad), status: "maybe", rsvp_option: rsvp_options(:full_weekend))
    sign_in_as "examplefamily"

    get event_path(events(:weekend_trip))
    assert_select "input[type=radio][name=?][value=maybe][checked]", "rsvps[#{people(:smith_dad).id}][status]"
    assert_select "select[name=?] option[selected][value=?]", "rsvps[#{people(:smith_dad).id}][rsvp_option_id]", rsvp_options(:full_weekend).id.to_s
  end

  test "family RSVPs with an option, and can change both later" do
    sign_in_as "examplefamily"
    event = events(:weekend_trip)

    rsvp_to event, people(:smith_dad) => option_answer("attending", rsvp_options(:full_weekend)),
                   people(:smith_lion) => option_answer("maybe", rsvp_options(:day_trip))
    assert_redirected_to event_path(event)
    assert_equal rsvp_options(:full_weekend), Rsvp.find_by!(event: event, person: people(:smith_dad)).rsvp_option
    assert_equal rsvp_options(:day_trip), Rsvp.find_by!(event: event, person: people(:smith_lion)).rsvp_option

    assert_no_difference "Rsvp.count" do
      rsvp_to event, people(:smith_dad) => option_answer("attending", rsvp_options(:day_trip))
    end
    assert_equal rsvp_options(:day_trip), Rsvp.find_by!(event: event, person: people(:smith_dad)).rsvp_option
  end

  test "attending or maybe without an option saves nothing and names the person" do
    sign_in_as "examplefamily"
    event = events(:weekend_trip)

    assert_no_difference "Rsvp.count" do
      rsvp_to event, people(:smith_lion) => option_answer("attending", rsvp_options(:full_weekend)),
                     people(:smith_dad) => option_answer("maybe", nil)
    end
    assert_redirected_to event_path(event)
    follow_redirect!
    assert_match "Sam Smith: Rsvp option must be chosen. Nothing was saved.", response.body
    assert_nil status_of(event, people(:smith_lion)), "the valid answer isn't saved on its own"
  end

  test "an option select left blank for someone who hasn't answered is ignored" do
    sign_in_as "examplefamily"
    event = events(:weekend_trip)

    assert_difference "Rsvp.count", 1 do
      rsvp_to event, people(:smith_dad) => option_answer("attending", rsvp_options(:day_trip)),
                     people(:smith_lion) => { rsvp_option_id: "" }
    end
    assert_nil status_of(event, people(:smith_lion))
  end

  test "not attending needs no option and drops one that was sent" do
    sign_in_as "examplefamily"
    event = events(:weekend_trip)

    rsvp_to event, people(:smith_dad) => option_answer("not_attending", nil),
                   people(:smith_lion) => option_answer("not_attending", rsvp_options(:full_weekend))
    assert_redirected_to event_path(event)
    assert_nil Rsvp.find_by!(event: event, person: people(:smith_dad)).rsvp_option
    assert_nil Rsvp.find_by!(event: event, person: people(:smith_lion)).rsvp_option
  end

  test "switching an answer to not attending clears the option" do
    sign_in_as "examplefamily"
    event = events(:weekend_trip)

    rsvp_to event, people(:smith_dad) => option_answer("attending", rsvp_options(:full_weekend))
    rsvp_to event, people(:smith_dad) => option_answer("not_attending", nil)
    assert_nil Rsvp.find_by!(event: event, person: people(:smith_dad)).rsvp_option
  end

  test "another event's option is rejected" do
    other = RsvpOption.create!(event: events(:campout), name: "Overnight")
    sign_in_as "examplefamily"

    assert_no_difference "Rsvp.count" do
      rsvp_to events(:weekend_trip), people(:smith_dad) => option_answer("attending", other)
    end
    follow_redirect!
    assert_match "isn&#39;t an option for this event", response.body
  end

  test "an option can't be sent for an event that has none" do
    sign_in_as "examplefamily"

    assert_no_difference "Rsvp.count" do
      rsvp_to events(:campout), people(:smith_dad) => option_answer("attending", rsvp_options(:day_trip))
    end
    follow_redirect!
    assert_match "isn&#39;t an option for this event", response.body
  end

  test "after the deadline families see their option, or that one is still needed" do
    Rsvp.create!(event: events(:weekend_trip), person: people(:smith_dad), status: "attending", rsvp_option: rsvp_options(:full_weekend))
    sign_in_as "examplefamily"

    travel_to events(:weekend_trip).ends_at + 1.minute do
      get event_path(events(:weekend_trip))
      assert_select "form[action=?]", event_rsvp_path(events(:weekend_trip)), count: 0
      assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*Attending - Full weekend/
      assert_select "li", text: /Lily Smith\s*Lion\s*No response/
    end
  end

  test "a response whose option was deleted reads as needing a choice" do
    rsvp = Rsvp.create!(event: events(:weekend_trip), person: people(:smith_dad), status: "attending", rsvp_option: rsvp_options(:full_weekend))
    rsvp_options(:full_weekend).destroy!
    assert_nil rsvp.reload.rsvp_option
    sign_in_as "examplefamily"

    travel_to events(:weekend_trip).ends_at + 1.minute do
      get event_path(events(:weekend_trip))
      assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*Attending - choose an option/
    end
  end

  test "admin roll-up shows each person's option and a count per option" do
    Rsvp.create!(event: events(:weekend_trip), person: people(:smith_dad), status: "attending", rsvp_option: rsvp_options(:full_weekend))
    Rsvp.create!(event: events(:weekend_trip), person: people(:smith_lion), status: "maybe", rsvp_option: rsvp_options(:day_trip))
    sign_in_as "adminfamily"

    get event_path(events(:weekend_trip))
    assert_select "p", text: /Attending \(2\)/ # Ben (fixture, day trip) and Sam (full weekend)
    assert_select "p", text: /Day trip only: 1, Full weekend: 1/
    assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*\(The Example Family\)\s*- Full weekend/
    assert_select "li", text: /Ben Jones\s*Bear\s*\(The Joneses\)\s*- Day trip only/
    assert_select "li", text: /Lily Smith\s*Lion\s*\(The Example Family\)\s*- Day trip only/
    assert_select "p", text: /Maybe \(1\)/
  end

  test "roll-up flags attending responses that have no option chosen" do
    rsvps(:jones_bear_weekend_trip).update_columns(rsvp_option_id: nil)
    sign_in_as "adminfamily"

    get event_path(events(:weekend_trip))
    assert_select "p", text: /No option chosen: 1/
    assert_select "li", text: /Ben Jones\s*Bear\s*\(The Joneses\)\s*- no option chosen/
  end

  test "events without options keep the plain roll-up" do
    sign_in_as "adminfamily"

    get event_path(events(:pack_meeting))
    assert_no_match "No option chosen", response.body
    assert_select "li", text: /Sam Smith\s*Adult \(Lion\)\s*\(The Example Family\)\s*\z/
  end

  # --- den badges ---

  test "the RSVP form shows each person's den next to their name" do
    sign_in_as "examplefamily"

    get event_path(events(:pack_meeting))
    assert_select "fieldset span.rounded-full", text: "Adult (Lion)", count: 1
    assert_select "fieldset span.rounded-full", text: "Lion", count: 1
    assert_select "fieldset", text: /Sam Smith\s*Adult \(Lion\)/
    assert_select "fieldset", text: /Lily Smith\s*Lion/
  end

  test "after the deadline the read-only list still shows the den badges" do
    sign_in_as "examplefamily"

    travel_to events(:pack_meeting).ends_at + 1.minute do
      get event_path(events(:pack_meeting))
      assert_select "li span.rounded-full", text: "Adult (Lion)", count: 1
      assert_select "li span.rounded-full", text: "Lion", count: 1
    end
  end

  test "the admin roll-up shows each person's den" do
    sign_in_as "adminfamily"

    get event_path(events(:pack_meeting))
    assert_select "li span.rounded-full", text: "Adult", count: Person.adult.select { |p| p.family_dens.empty? }.count
    assert_select "li span.rounded-full", text: "Adult (Lion)", count: 1
    assert_select "li span.rounded-full", text: "Lion", count: Person.lion.count
    assert_select "li span.rounded-full", text: "Bear", count: Person.bear.count
  end
end
