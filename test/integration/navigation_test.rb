require "test_helper"

class NavigationTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  test "the nav appears on a non-root page, hiding admin-only links for a non-admin" do
    sign_in_as "examplefamily"

    get events_path
    assert_response :success
    assert_select "header nav a[href=?]", root_path, text: "Pack It In"
    assert_select "header a[href=?]", events_path, text: "Events"
    assert_select "header a[href=?]", family_path(families(:one)), text: "My Family"
    assert_select "header a", text: "Families", count: 0
    assert_select "header a", text: "Funds", count: 0
  end

  test "the nav shows admin-only links for an admin on a non-root page" do
    sign_in_as "adminfamily"

    get events_path
    assert_response :success
    assert_select "header a[href=?]", families_path, text: "Families"
    assert_select "header a[href=?]", funds_path, text: "Funds"
  end

  test "the nav shows only the brand, events and a login link for a guest" do
    get new_family_session_path
    assert_response :success
    assert_select "header nav a[href=?]", root_path, text: "Pack It In"
    assert_select "header a[href=?]", new_family_session_path, text: "Log in"
    assert_select "header a[href=?]", events_path, text: "Events"
    assert_select "header a", text: "My Family", count: 0
    assert_select "header a", text: "Families", count: 0
    assert_select "header a", text: "Funds", count: 0
  end

  test "the nav includes a hamburger toggle and a mobile menu panel" do
    sign_in_as "examplefamily"

    get events_path
    assert_select "header button[data-action=?][aria-controls=?]", "nav#toggle", "mobile-menu"
    assert_select "header div#mobile-menu[data-nav-target=?]", "menu"
  end

  test "the brand and page title use APP_NAME when set" do
    original = ENV["APP_NAME"]
    ENV["APP_NAME"] = "Troop 123"

    get root_path
    assert_response :success
    assert_select "header nav a[href=?]", root_path, text: "Troop 123"
    assert_select "title", "Troop 123"
  ensure
    ENV["APP_NAME"] = original
  end
end
