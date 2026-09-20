require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "home page is public" do
    get root_path
    assert_response :success
    assert_select "a", "Log in"
  end

  test "sign up with username and password" do
    assert_difference "Family.count", 1 do
      post family_registration_path, params: { family: { username: "brandnew", password: "password123", password_confirmation: "password123", **profile_params } }
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_match "brandnew", response.body
  end

  test "sign up requires the name and address" do
    assert_no_difference "Family.count" do
      post family_registration_path, params: { family: { username: "brandnew", password: "password123", password_confirmation: "password123" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation", /Name can't be blank/
    assert_select "#error_explanation", /Zip can't be blank/
  end

  test "sign up with invalid data re-renders form" do
    assert_no_difference "Family.count" do
      post family_registration_path, params: { family: { username: "", password: "x", password_confirmation: "y" } }
    end
    assert_response :unprocessable_entity
  end

  test "sign in and sign out" do
    post family_session_path, params: { family: { username: "examplefamily", password: "password123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "examplefamily", response.body

    delete destroy_family_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select "a", "Log in"
  end

  test "username sign in is case insensitive" do
    post family_session_path, params: { family: { username: "ExampleFamily", password: "password123" } }
    assert_redirected_to root_path
  end

  test "wrong password is rejected" do
    post family_session_path, params: { family: { username: "examplefamily", password: "nope" } }
    assert_response :unprocessable_entity
  end

  test "signed-in family cannot destroy its own account" do
    post family_session_path, params: { family: { username: "examplefamily", password: "password123" } }

    assert_no_difference "Family.count" do
      delete family_registration_path
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
    assert_match "examplefamily", response.body, "should still be signed in"
  end

  test "edit account page has no cancel account button" do
    post family_session_path, params: { family: { username: "examplefamily", password: "password123" } }
    get edit_family_registration_path
    assert_response :success
    assert_select "input[type=submit][value=Update]"
    assert_select "button, input[type=submit]", text: /cancel my account/i, count: 0
    assert_select "input[name=_method][value=delete]", count: 0
  end

  test "sign up and edit account forms include the name and address fields" do
    get new_family_registration_path
    %w[name street_address city state zip].each { |field| assert_select "[name=?]", "family[#{field}]" }

    post family_session_path, params: { family: { username: "examplefamily", password: "password123" } }
    get edit_family_registration_path
    assert_select "input[name=?][value=?]", "family[street_address]", "100 Main St"
    assert_select "select[name=?] option[selected][value=tx]", "family[state]"
  end

  test "family can update its own name and address from the account page" do
    post family_session_path, params: { family: { username: "examplefamily", password: "password123" } }
    put family_registration_path, params: { family: { name: "The Examples", street_address: "9 Oak Ln", city: "Dallas", state: "tx", zip: "75201", current_password: "password123" } }

    assert_redirected_to root_path
    families(:one).reload
    assert_equal [ "The Examples", "9 Oak Ln", "Dallas", "tx", "75201" ], families(:one).values_at(:name, :street_address, :city, :state, :zip)
  end

  test "sign up cannot make a family an admin" do
    post family_registration_path, params: { family: { username: "sneaky", password: "password123", password_confirmation: "password123", admin: "1", **profile_params } }
    assert_not Family.find_by!(username: "sneaky").admin?
  end

  test "account update cannot make a family an admin" do
    post family_session_path, params: { family: { username: "examplefamily", password: "password123" } }
    put family_registration_path, params: { family: { username: "examplefamily", admin: "1", current_password: "password123" } }
    assert_not families(:one).reload.admin?
  end

  test "admin family cannot destroy its own account either" do
    post family_session_path, params: { family: { username: "adminfamily", password: "password123" } }

    assert_no_difference "Family.count" do
      delete family_registration_path
    end
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  test "guest cannot destroy a family either" do
    assert_no_difference "Family.count" do
      delete family_registration_path
    end
    assert_redirected_to new_family_session_path
  end
end
