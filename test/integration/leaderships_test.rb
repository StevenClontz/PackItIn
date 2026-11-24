require "test_helper"

class LeadershipsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  test "an admin adds and removes a leadership role" do
    mom = people(:garcia_mom)
    sign_in_as "adminfamily"

    assert_difference -> { mom.leaderships.count }, 1 do
      post person_leaderships_path(mom), params: { leadership: { role: "den_leader", den: "wolf" } }
    end
    assert_redirected_to person_path(mom)
    follow_redirect!
    assert_select "#leadership_roles", text: /Den Leader \(Wolf\)/

    leadership = mom.leaderships.last
    assert_difference -> { mom.leaderships.count }, -1 do
      delete leadership_path(leadership)
    end
    assert_redirected_to person_path(mom)
  end

  test "a den role without a den re-renders the person page with an error" do
    mom = people(:garcia_mom)
    sign_in_as "adminfamily"

    assert_no_difference -> { Leadership.count } do
      post person_leaderships_path(mom), params: { leadership: { role: "den_leader", den: "" } }
    end
    assert_response :unprocessable_content
    assert_select "#error_explanation", text: /Den must be chosen for this role/
  end

  test "non-admin families can't add or remove roles, even for their own people" do
    sign_in_as "examplefamily"

    assert_no_difference -> { Leadership.count } do
      post person_leaderships_path(people(:smith_dad)), params: { leadership: { role: "treasurer" } }
      delete leadership_path(leaderships(:sam_cubmaster))
    end
  end

  test "guests are sent to sign in" do
    post person_leaderships_path(people(:smith_dad)), params: { leadership: { role: "treasurer" } }
    assert_redirected_to new_family_session_path
  end

  test "a family sees its own adult's roles but no management controls" do
    sign_in_as "examplefamily"
    get person_path(people(:smith_dad))

    assert_select "#leadership_roles", text: /Cubmaster/
    assert_select "#leadership_roles button", count: 0
    assert_select "#add_leadership", count: 0
  end

  test "admins see the add form on adults but not on youth" do
    sign_in_as "adminfamily"

    get person_path(people(:smith_dad))
    assert_select "#add_leadership form[action=?]", person_leaderships_path(people(:smith_dad))
    assert_select "#leadership_roles button", text: "Remove"

    get person_path(people(:smith_lion))
    assert_select "#add_leadership", count: 0
    assert_select "#leadership_roles", count: 0
  end
end
