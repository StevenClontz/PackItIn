require "test_helper"

class EventsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  def valid_event_params(**overrides)
    { event: { title: "Cookout", description: "Burgers", starts_at: "2026-10-03T18:00", ends_at: "2026-10-03T19:30" }.merge(overrides) }
  end

  # --- guests ---

  test "guests are sent to sign in" do
    [ events_path, event_path(events(:pack_meeting)), new_event_path, edit_event_path(events(:pack_meeting)) ].each do |path|
      get path
      assert_redirected_to new_family_session_path, "GET #{path}"
    end

    assert_no_difference "Event.count" do
      post events_path, params: valid_event_params
      patch event_path(events(:pack_meeting)), params: { event: { title: "X" } }
      delete event_path(events(:pack_meeting))
    end
    assert_equal "Pack Meeting", events(:pack_meeting).reload.title
  end

  # --- non-admin: read only ---

  test "non-admin sees upcoming and past events with no controls" do
    sign_in_as "examplefamily"

    get events_path
    assert_response :success
    assert_select "h3", "Upcoming"
    assert_select "h3", "Past"
    assert_select "a[href=?]", event_path(events(:pack_meeting)), text: "Pack Meeting"
    assert_select "a[href=?]", event_path(events(:campout)), text: "Fall Campout"
    assert_select "a[href=?]", event_path(events(:past_hike)), text: "Trail Hike"
    assert_select "a", text: "New event", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "index puts each event in the right section" do
    sign_in_as "examplefamily"
    get events_path

    upcoming, past = response.body.split("<h3", 3).last(2)
    assert_includes upcoming, "Pack Meeting"
    assert_includes upcoming, "Fall Campout"
    assert_not_includes upcoming, "Trail Hike"
    assert_includes past, "Trail Hike"
  end

  test "non-admin can view an event but sees no edit or delete controls" do
    sign_in_as "examplefamily"

    get event_path(events(:pack_meeting))
    assert_response :success
    assert_select "h2", "Pack Meeting"
    assert_match "Monthly pack meeting", response.body
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "non-admin cannot create, edit, update or delete events" do
    sign_in_as "examplefamily"

    get new_event_path
    assert_denied
    get edit_event_path(events(:pack_meeting))
    assert_denied

    assert_no_difference "Event.count" do
      post events_path, params: valid_event_params
      assert_denied
      delete event_path(events(:pack_meeting))
      assert_denied
    end

    patch event_path(events(:pack_meeting)), params: { event: { title: "Hijacked" } }
    assert_denied
    assert_equal "Pack Meeting", events(:pack_meeting).reload.title
  end

  test "home page links to events for signed-in families" do
    sign_in_as "examplefamily"
    get root_path
    assert_select "a[href=?]", events_path, text: "Pack Events"
  end

  # --- admin ---

  test "admin index shows New event, Edit and Delete" do
    sign_in_as "adminfamily"
    get events_path

    assert_select "a", text: "New event", count: 1
    assert_select "a[href=?]", edit_event_path(events(:pack_meeting)), text: "Edit"
    assert_select "form[action=?] button", event_path(events(:pack_meeting)), text: "Delete"
  end

  test "admin creates an event with times entered in Central Time" do
    sign_in_as "adminfamily"

    get new_event_path
    assert_response :success
    assert_select "input[type=datetime-local][name=?]", "event[starts_at]"
    assert_select "input[type=datetime-local][name=?]", "event[ends_at]"
    assert_select "input[type=datetime-local][name=?]", "event[rsvp_deadline_at]"

    travel_to Time.zone.local(2026, 9, 1) do
      assert_difference "Event.count", 1 do
        post events_path, params: valid_event_params(rsvp_deadline_at: "2026-10-02T12:00")
      end
      event = Event.find_by!(title: "Cookout")
      assert_redirected_to event_path(event)

      assert_equal Time.utc(2026, 10, 3, 23, 0), event.starts_at.utc, "6 PM CDT is 23:00 UTC"
      assert_equal Time.utc(2026, 10, 2, 17, 0), event.rsvp_deadline_at.utc

      follow_redirect!
      assert_match "Sat, Oct 3, 6:00 PM to 7:30 PM CDT", response.body
      assert_match "RSVP by Fri, Oct 2, 12:00 PM CDT", response.body
    end
  end

  test "creating with invalid data re-renders the form" do
    sign_in_as "adminfamily"

    assert_no_difference "Event.count" do
      post events_path, params: valid_event_params(title: "", ends_at: "2026-10-03T17:00")
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation", /Title can't be blank/
    assert_select "#error_explanation", /Ends at must be after the start time/
  end

  test "admin edits an event and can set and clear the RSVP deadline" do
    sign_in_as "adminfamily"
    event = events(:pack_meeting)

    get edit_event_path(event)
    assert_response :success
    assert_select "input[name=?][value=?]", "event[title]", "Pack Meeting"

    patch event_path(event), params: { event: { title: "Pack Meeting!", rsvp_deadline_at: "2026-10-01T09:00" } }
    assert_redirected_to event_path(event)
    event.reload
    assert_equal "Pack Meeting!", event.title
    assert_equal Time.utc(2026, 10, 1, 14, 0), event.rsvp_deadline_at.utc

    patch event_path(event), params: { event: { rsvp_deadline_at: "" } }
    assert_nil event.reload.rsvp_deadline_at
    assert_equal event.ends_at, event.rsvp_closes_at
  end

  test "updating with invalid data re-renders the form and changes nothing" do
    sign_in_as "adminfamily"

    patch event_path(events(:pack_meeting)), params: { event: { title: "" } }
    assert_response :unprocessable_entity
    assert_select "#error_explanation"
    assert_equal "Pack Meeting", events(:pack_meeting).reload.title
  end

  test "admin deletes an event and its RSVPs" do
    sign_in_as "adminfamily"

    assert_difference({ "Event.count" => -1, "Rsvp.count" => -3 }) do # pack_meeting has 3 RSVPs
      delete event_path(events(:pack_meeting))
    end
    assert_redirected_to events_path
    assert_response :see_other
  end

  test "event description is escaped" do
    events(:campout).update!(description: "<script>alert(1)</script>")
    sign_in_as "examplefamily"

    get event_path(events(:campout))
    assert_no_match "<script>alert(1)</script>", response.body
    assert_match "&lt;script&gt;", response.body
  end

  test "a multi-day event shows both full timestamps" do
    sign_in_as "examplefamily"
    get event_path(events(:campout))

    assert_match(/\w{3}, \w{3} \d+, 5:00 PM C[DS]T to \w{3}, \w{3} \d+, 11:00 AM C[DS]T/, response.body)
  end

  # --- event account ---

  test "the event page has no Event Account link for a non-admin" do
    transact from: :outside, to: events(:campout), dollars: 100, memo: "Sponsor gift"
    sign_in_as "examplefamily"

    get event_path(events(:campout))
    assert_response :success
    assert_select "a[href=?]", event_account_path(events(:campout)), count: 0
    assert_no_match "Sponsor gift", response.body
    assert_no_match "Statement", response.body
  end

  test "the event page links to the event's account instead of listing its transactions, for an admin" do
    transact from: :outside, to: events(:campout), dollars: 100, memo: "Sponsor gift"
    sign_in_as "adminfamily"

    get event_path(events(:campout))
    assert_response :success
    assert_select "a[href=?]", event_account_path(events(:campout)), text: "View Event Account"
    assert_select "span", text: /balance\s*\$100\.00/
    assert_select "table", count: 0
    assert_no_match "Sponsor gift", response.body
    assert_no_match "Statement", response.body
  end

  test "an admin can't delete an event that has account activity" do
    transact from: :outside, to: events(:campout), dollars: 5
    sign_in_as "adminfamily"

    assert_no_difference [ "Event.count", "Rsvp.count" ] do
      delete event_path(events(:campout))
    end
    assert_redirected_to event_path(events(:campout))
    follow_redirect!
    assert_match "Fall Campout has Event Account activity and can&#39;t be deleted", response.body
  end
end
