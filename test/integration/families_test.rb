require "test_helper"

class FamiliesTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  # --- guests ---

  test "guests are sent to sign in" do
    [ families_path, family_path(families(:one)), new_family_path, edit_family_path(families(:one)) ].each do |path|
      get path
      assert_redirected_to new_family_session_path, "GET #{path}"
    end
  end

  # --- viewing ---

  test "any signed-in family can view the index and show pages" do
    sign_in_as "examplefamily"

    get families_path
    assert_response :success
    assert_select "a", "joneses"
    assert_select "a", "adminfamily"

    get family_path(families(:two))
    assert_response :success
    assert_match "joneses", response.body
  end

  test "non-admin index shows only the controls they may use" do
    sign_in_as "examplefamily"
    get families_path

    assert_select "a", text: "New family", count: 0
    assert_select "button", text: "Delete", count: 0
    assert_select "a[href=?]", edit_family_path(families(:one)), count: 1
    assert_select "a[href=?]", edit_family_path(families(:two)), count: 0
  end

  test "admin index shows New, Edit everywhere and Delete for others but not themselves" do
    sign_in_as "adminfamily"
    get families_path

    assert_select "a", text: "New family", count: 1
    assert_select "a[href=?]", edit_family_path(families(:one)), count: 1
    assert_select "a[href=?]", edit_family_path(families(:admin)), count: 1
    assert_select "form[action=?] button", family_path(families(:one)), text: "Delete"
    assert_select "form[action=?]", family_path(families(:admin)), count: 0
  end

  # --- new / create ---

  test "non-admin cannot open new or create" do
    sign_in_as "examplefamily"

    get new_family_path
    assert_denied

    assert_no_difference "Family.count" do
      post families_path, params: { family: { username: "nope", password: "password123", password_confirmation: "password123" } }
    end
    assert_denied
  end

  test "admin creates a family, optionally an admin" do
    sign_in_as "adminfamily"

    get new_family_path
    assert_response :success

    assert_difference "Family.count", 1 do
      post families_path, params: { family: { username: "newbies", password: "password123", password_confirmation: "password123", admin: "1" } }
    end
    created = Family.find_by!(username: "newbies")
    assert_redirected_to family_path(created)
    assert created.admin?
    assert created.valid_password?("password123")
  end

  test "creating with invalid data re-renders the form" do
    sign_in_as "adminfamily"

    assert_no_difference "Family.count" do
      post families_path, params: { family: { username: "", password: "x", password_confirmation: "y" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation"
  end

  # --- editing others ---

  test "non-admin cannot edit or update another family" do
    sign_in_as "examplefamily"

    get edit_family_path(families(:two))
    assert_denied

    patch family_path(families(:two)), params: { family: { username: "hijacked" } }
    assert_denied
    assert_equal "joneses", families(:two).reload.username
  end

  test "admin edits another family without a current password" do
    sign_in_as "adminfamily"

    get edit_family_path(families(:two))
    assert_response :success
    assert_select "input[name=?]", "family[current_password]", count: 0

    patch family_path(families(:two)), params: { family: { username: "joneses2", password: "newpassword1", password_confirmation: "newpassword1" } }
    assert_redirected_to family_path(families(:two))
    families(:two).reload
    assert_equal "joneses2", families(:two).username
    assert families(:two).valid_password?("newpassword1")
  end

  test "blank password on edit keeps the existing password" do
    sign_in_as "adminfamily"

    patch family_path(families(:two)), params: { family: { username: "joneses2", password: "", password_confirmation: "" } }
    assert_redirected_to family_path(families(:two))
    assert families(:two).reload.valid_password?("password123")
  end

  # --- editing yourself ---

  test "non-admin can rename themselves without a current password" do
    sign_in_as "examplefamily"

    patch family_path(families(:one)), params: { family: { username: "examplefamily2" } }
    assert_redirected_to family_path(families(:one))
    assert_equal "examplefamily2", families(:one).reload.username
  end

  test "changing your own password requires the current password and keeps you signed in" do
    sign_in_as "examplefamily"

    get edit_family_path(families(:one))
    assert_select "input[name=?]", "family[current_password]"

    patch family_path(families(:one)), params: { family: { password: "newpassword1", password_confirmation: "newpassword1", current_password: "password123" } }
    assert_redirected_to family_path(families(:one))
    assert families(:one).reload.valid_password?("newpassword1")

    get families_path
    assert_response :success, "should still be signed in after changing password"
  end

  test "changing your own password with a wrong or missing current password is rejected" do
    sign_in_as "examplefamily"

    [ "wrong", "" ].each do |current|
      patch family_path(families(:one)), params: { family: { password: "newpassword1", password_confirmation: "newpassword1", current_password: current } }
      assert_response :unprocessable_entity
      assert_select "#error_explanation"
      assert families(:one).reload.valid_password?("password123"), "password must be unchanged (current_password: #{current.inspect})"
    end
  end

  # --- the admin flag ---

  test "non-admin cannot grant themselves admin" do
    sign_in_as "examplefamily"

    patch family_path(families(:one)), params: { family: { username: "examplefamily", admin: "1" } }
    assert_not families(:one).reload.admin?
  end

  test "admin can promote and demote another family" do
    sign_in_as "adminfamily"

    patch family_path(families(:two)), params: { family: { admin: "1" } }
    assert families(:two).reload.admin?

    patch family_path(families(:two)), params: { family: { admin: "0" } }
    assert_not families(:two).reload.admin?
  end

  test "admin cannot demote themselves and sees no admin checkbox on their own form" do
    sign_in_as "adminfamily"

    get edit_family_path(families(:admin))
    assert_select "input[type=checkbox][name=?]", "family[admin]", count: 0

    patch family_path(families(:admin)), params: { family: { username: "adminfamily", admin: "0" } }
    assert families(:admin).reload.admin?

    get edit_family_path(families(:two))
    assert_select "input[type=checkbox][name=?]", "family[admin]", count: 1
  end

  # --- destroy ---

  test "admin deletes another family" do
    sign_in_as "adminfamily"

    assert_difference "Family.count", -1 do
      delete family_path(families(:two))
    end
    assert_redirected_to families_path
    assert_response :see_other
  end

  test "admin cannot delete themselves" do
    sign_in_as "adminfamily"

    assert_no_difference "Family.count" do
      delete family_path(families(:admin))
    end
    assert_denied
  end

  test "non-admin cannot delete any family, even themselves" do
    sign_in_as "examplefamily"

    assert_no_difference "Family.count" do
      delete family_path(families(:two))
      assert_denied
      delete family_path(families(:one))
      assert_denied
    end
  end

  # --- Devise moved to /account ---

  test "devise pages live under /account" do
    assert_equal "/account/sign_in", new_family_session_path
    assert_equal "/account/sign_up", new_family_registration_path
    assert_equal "/account/edit", edit_family_registration_path
  end
end
