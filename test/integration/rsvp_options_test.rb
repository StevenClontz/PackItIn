require "test_helper"

class RsvpOptionsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  def option_params(**overrides)
    { rsvp_option: { name: "Overnight", description: "Friday night only" }.merge(overrides) }
  end

  # --- guests ---

  test "guests are sent to sign in" do
    event = events(:weekend_trip)
    [ new_event_rsvp_option_path(event), edit_event_rsvp_option_path(event, rsvp_options(:day_trip)) ].each do |path|
      get path
      assert_redirected_to new_family_session_path, "GET #{path}"
    end

    assert_no_difference "RsvpOption.count" do
      post event_rsvp_options_path(event), params: option_params
      delete event_rsvp_option_path(event, rsvp_options(:day_trip))
    end
    assert_equal "Day trip only", rsvp_options(:day_trip).reload.name
  end

  # --- families: can see, can't change ---

  test "families see the ways to attend with their descriptions and no controls" do
    sign_in_as "examplefamily"

    get event_path(events(:weekend_trip))
    assert_response :success
    assert_select "h3", "Ways to attend"
    assert_select "li", text: /Day trip only\s*- \$25\.00 per person\s*Saturday only, home by dinner\./
    assert_select "li", text: /Full weekend\s*- \$60\.00 per person\s*Both days, with the overnight camp\./
    assert_select "a", text: "Add option", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "families can't add, edit or delete options" do
    sign_in_as "examplefamily"
    event = events(:weekend_trip)

    get new_event_rsvp_option_path(event)
    assert_denied
    get edit_event_rsvp_option_path(event, rsvp_options(:day_trip))
    assert_denied

    assert_no_difference "RsvpOption.count" do
      post event_rsvp_options_path(event), params: option_params
      assert_denied
      delete event_rsvp_option_path(event, rsvp_options(:day_trip))
      assert_denied
    end

    patch event_rsvp_option_path(event, rsvp_options(:day_trip)), params: option_params(name: "Hijacked")
    assert_denied
    assert_equal "Day trip only", rsvp_options(:day_trip).reload.name
  end

  # --- admin ---

  test "admin sees option controls, and Add option even when an event has none" do
    sign_in_as "adminfamily"

    get event_path(events(:weekend_trip))
    assert_select "a[href=?]", edit_event_rsvp_option_path(events(:weekend_trip), rsvp_options(:day_trip)), text: "Edit"
    assert_select "form[action=?] button", event_rsvp_option_path(events(:weekend_trip), rsvp_options(:day_trip)), text: "Delete"
    assert_select "a[href=?]", new_event_rsvp_option_path(events(:weekend_trip)), text: "Add option"

    get event_path(events(:campout))
    assert_select "h3", "Ways to attend"
    assert_match "No options yet", response.body
    assert_select "a[href=?]", new_event_rsvp_option_path(events(:campout)), text: "Add option"
  end

  test "an event without options shows families no Ways to attend section" do
    sign_in_as "examplefamily"

    get event_path(events(:campout))
    assert_select "h3", text: "Ways to attend", count: 0
  end

  test "admin adds an option" do
    sign_in_as "adminfamily"

    get new_event_rsvp_option_path(events(:campout))
    assert_response :success
    assert_select "input[name=?]", "rsvp_option[name]"
    assert_select "textarea[name=?]", "rsvp_option[description]"

    assert_difference "RsvpOption.count", 1 do
      post event_rsvp_options_path(events(:campout)), params: option_params
    end
    assert_redirected_to event_path(events(:campout))
    option = events(:campout).rsvp_options.find_by!(name: "Overnight")
    assert_equal "Friday night only", option.description
    follow_redirect!
    assert_match "Option added.", response.body
  end

  test "adding an invalid or duplicate option re-renders the form" do
    sign_in_as "adminfamily"

    assert_no_difference "RsvpOption.count" do
      post event_rsvp_options_path(events(:weekend_trip)), params: option_params(name: "")
      assert_response :unprocessable_entity
      assert_select "#error_explanation", /Name can't be blank/

      post event_rsvp_options_path(events(:weekend_trip)), params: option_params(name: "full weekend")
      assert_response :unprocessable_entity
      assert_select "#error_explanation", /Name has already been taken/
    end
  end

  test "admin edits an option" do
    sign_in_as "adminfamily"
    event = events(:weekend_trip)

    get edit_event_rsvp_option_path(event, rsvp_options(:day_trip))
    assert_response :success
    assert_select "input[name=?][value=?]", "rsvp_option[name]", "Day trip only"

    patch event_rsvp_option_path(event, rsvp_options(:day_trip)), params: option_params(name: "Saturday only", description: "")
    assert_redirected_to event_path(event)
    assert_equal "Saturday only", rsvp_options(:day_trip).reload.name
    assert_equal rsvp_options(:day_trip), rsvps(:jones_bear_weekend_trip).reload.rsvp_option, "responses follow a rename"

    patch event_rsvp_option_path(event, rsvp_options(:day_trip)), params: option_params(name: "")
    assert_response :unprocessable_entity
    assert_equal "Saturday only", rsvp_options(:day_trip).reload.name
  end

  test "an option is only reachable through its own event" do
    sign_in_as "adminfamily"

    get edit_event_rsvp_option_path(events(:campout), rsvp_options(:day_trip))
    assert_response :not_found

    delete event_rsvp_option_path(events(:campout), rsvp_options(:day_trip))
    assert_response :not_found
    assert RsvpOption.exists?(rsvp_options(:day_trip).id)
  end

  test "admin deletes an option, keeping the responses that chose it" do
    sign_in_as "adminfamily"

    assert_difference "RsvpOption.count", -1 do
      assert_no_difference "Rsvp.count" do
        delete event_rsvp_option_path(events(:weekend_trip), rsvp_options(:day_trip))
      end
    end
    assert_redirected_to event_path(events(:weekend_trip))
    assert_response :see_other
    follow_redirect!
    assert_match "Option deleted. 1 response will need a new choice.", response.body

    rsvp = rsvps(:jones_bear_weekend_trip).reload
    assert_equal "attending", rsvp.status
    assert_nil rsvp.rsvp_option
  end

  test "deleting an option nobody chose doesn't mention responses" do
    sign_in_as "adminfamily"

    delete event_rsvp_option_path(events(:weekend_trip), rsvp_options(:full_weekend))
    follow_redirect!
    assert_match "Option deleted.", response.body
    assert_no_match "will need a new choice", response.body
  end

  # --- cost ---

  test "the option form has an optional cost field" do
    sign_in_as "adminfamily"

    get new_event_rsvp_option_path(events(:campout))
    assert_select "input[name=?]", "rsvp_option[cost_dollars]"
    assert_match "Per person. Leave blank if free.", response.body
  end

  test "admin adds an option with a cost, and without one" do
    sign_in_as "adminfamily"

    post event_rsvp_options_path(events(:campout)), params: option_params(cost_dollars: "$40")
    assert_redirected_to event_path(events(:campout))
    assert_equal 4000, events(:campout).rsvp_options.find_by!(name: "Overnight").cost_cents

    post event_rsvp_options_path(events(:campout)), params: option_params(name: "Free visit", cost_dollars: "")
    assert_nil events(:campout).rsvp_options.find_by!(name: "Free visit").cost_cents
  end

  test "an invalid cost re-renders the form with what was typed" do
    sign_in_as "adminfamily"

    assert_no_difference "RsvpOption.count" do
      post event_rsvp_options_path(events(:campout)), params: option_params(cost_dollars: "twenty")
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation", /Cost must be a dollar amount such as 25 or 25\.50/
    assert_select "input[name=?][value=?]", "rsvp_option[cost_dollars]", "twenty"
  end

  test "admin edits and clears an option's cost" do
    sign_in_as "adminfamily"
    event = events(:weekend_trip)

    get edit_event_rsvp_option_path(event, rsvp_options(:day_trip))
    assert_select "input[name=?][value=?]", "rsvp_option[cost_dollars]", "25.00"

    patch event_rsvp_option_path(event, rsvp_options(:day_trip)), params: option_params(name: "Day trip only", cost_dollars: "30.5")
    assert_equal 3050, rsvp_options(:day_trip).reload.cost_cents

    patch event_rsvp_option_path(event, rsvp_options(:day_trip)), params: option_params(name: "Day trip only", cost_dollars: "")
    assert_nil rsvp_options(:day_trip).reload.cost_cents
  end

  test "families can't set a cost" do
    sign_in_as "examplefamily"

    patch event_rsvp_option_path(events(:weekend_trip), rsvp_options(:day_trip)), params: option_params(cost_dollars: "1")
    assert_denied
    assert_equal 2500, rsvp_options(:day_trip).reload.cost_cents
  end

  test "free options show no cost in the list" do
    rsvp_options(:day_trip).update!(cost_cents: nil)
    sign_in_as "examplefamily"

    get event_path(events(:weekend_trip))
    assert_select "li", text: /Day trip only\s*Saturday only/
    assert_no_match "Day trip only - ", response.body
  end
end
