require "test_helper"

class RsvpsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  def rsvp_to(event, responses)
    patch event_rsvp_path(event), params: { rsvps: responses.transform_keys { |person| person.id.to_s } }
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
      assert_select "input[type=radio][name=?]", "rsvps[#{person.id}]", count: 3
    end
    assert_select "input[type=radio][name=?][value=attending][checked]", "rsvps[#{people(:smith_dad).id}]"
    assert_select "input[type=radio][name=?][value=maybe][checked]", "rsvps[#{people(:smith_lion).id}]"
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
    assert_select "input[name=?]", "rsvps[#{people(:jones_bear).id}]", count: 0
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
    assert_select "input[type=radio][name=?][value=not_attending][checked]", "rsvps[#{people(:smith_lion).id}]"
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
    assert_match "nothing was saved", response.body
    assert_nil status_of(events(:campout), people(:smith_dad))
  end

  test "an unknown person is a 404 and an empty submission is rejected gently" do
    sign_in_as "examplefamily"

    patch event_rsvp_path(events(:campout)), params: { rsvps: { "0" => "attending" } }
    assert_response :not_found

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
      assert_select "li", text: /Sam Smith\s*No response/
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
    assert_select "p", text: /No response \(0\)/
    assert_select "li", text: /Sam Smith\s*\(The Example Family\)/
    assert_select "li", text: /Ben Jones\s*\(The Joneses\)/

    get event_path(events(:campout))
    assert_select "p", text: /No response \(3\)/
    assert_select "p", text: /Attending \(0\)/
  end

  test "an admin with people of their own still gets the form after the deadline, with a note" do
    families(:admin).people.create!(first_name: "Ada", last_name: "Admin", position: :adult)
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
end
