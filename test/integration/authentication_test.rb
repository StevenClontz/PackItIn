require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "home page is public" do
    get root_path
    assert_response :success
    assert_select "a", "Log in"
  end

  test "sign up with username and password" do
    assert_difference "Family.count", 1 do
      post family_registration_path, params: { family: { username: "brandnew", password: "password123", password_confirmation: "password123" } }
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_match "brandnew", response.body
  end

  test "sign up with invalid data re-renders form" do
    assert_no_difference "Family.count" do
      post family_registration_path, params: { family: { username: "", password: "x", password_confirmation: "y" } }
    end
    assert_response :unprocessable_entity
  end

  test "sign in and sign out" do
    post family_session_path, params: { family: { username: "smiths", password: "password123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "smiths", response.body

    delete destroy_family_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select "a", "Log in"
  end

  test "username sign in is case insensitive" do
    post family_session_path, params: { family: { username: "SMITHS", password: "password123" } }
    assert_redirected_to root_path
  end

  test "wrong password is rejected" do
    post family_session_path, params: { family: { username: "smiths", password: "nope" } }
    assert_response :unprocessable_entity
  end
end
