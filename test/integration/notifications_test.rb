require "test_helper"

class NotificationsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  # --- announcements ---

  test "admins can email an event to families" do
    sign_in_as "adminfamily"
    get event_path(events(:campout))
    assert_select "a[href=?]", new_event_announcement_path(events(:campout))

    get new_event_announcement_path(events(:campout))
    assert_response :success

    assert_enqueued_emails 1 do
      post event_announcement_path(events(:campout)), params: { note: "See you there" }
    end
    assert_redirected_to event_path(events(:campout))
    follow_redirect!
    assert_match "emailed to 1 adult", response.body
    assert_match "Announced", response.body
  end

  test "families and guests can't send announcements" do
    get new_event_announcement_path(events(:campout))
    assert_redirected_to new_family_session_path

    sign_in_as "examplefamily"
    get event_path(events(:campout))
    assert_select "a[href=?]", new_event_announcement_path(events(:campout)), count: 0

    assert_no_enqueued_emails do
      post event_announcement_path(events(:campout))
    end
    assert_redirected_to root_path
  end

  # --- unsubscribing ---

  test "the unsubscribe link asks before unsubscribing, and can be undone" do
    person = people(:smith_dad)
    token = person.generate_token_for(:unsubscribe)

    get unsubscribe_path(token)
    assert_response :success
    assert_not person.reload.email_opt_out?

    post unsubscribe_path(token)
    assert person.reload.email_opt_out?
    assert_not_includes Person.notifiable, person

    delete unsubscribe_path(token)
    assert_not person.reload.email_opt_out?
  end

  test "mail clients can unsubscribe in one click without a CSRF token" do
    ActionController::Base.allow_forgery_protection = true
    token = people(:smith_dad).generate_token_for(:unsubscribe)
    post unsubscribe_path(token), params: { "List-Unsubscribe" => "One-Click" }
    assert people(:smith_dad).reload.email_opt_out?
  ensure
    ActionController::Base.allow_forgery_protection = false
  end

  test "a bad unsubscribe token is rejected" do
    get unsubscribe_path("nope")
    assert_response :not_found
  end

  # --- family page toggle ---

  test "families can turn pack emails off and on for their own adults" do
    sign_in_as "examplefamily"
    get family_path(families(:one))
    assert_select "button", "Emails on"

    patch person_notifications_path(people(:smith_dad)), params: { email_opt_out: "1" }
    assert_redirected_to family_path(families(:one))
    assert people(:smith_dad).reload.email_opt_out?

    patch person_notifications_path(people(:smith_dad)), params: { email_opt_out: "0" }
    assert_not people(:smith_dad).reload.email_opt_out?
  end

  test "families can't change another family's email settings" do
    people(:jones_dad).update!(email: "tom@example.com")
    sign_in_as "examplefamily"
    patch person_notifications_path(people(:jones_dad)), params: { email_opt_out: "1" }
    assert_redirected_to root_path
    assert_not people(:jones_dad).reload.email_opt_out?
  end
end
