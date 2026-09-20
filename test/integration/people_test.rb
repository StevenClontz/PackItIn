require "test_helper"

class PeopleTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { username: username, password: password } }
  end

  def assert_denied
    assert_redirected_to root_path
    follow_redirect!
    assert_match "not authorized", response.body
  end

  def valid_person_params
    { person: { first_name: "Newt", last_name: "Smith", position: "tiger" } }
  end

  # --- guests ---

  test "guests are sent to sign in" do
    [
      family_people_path(families(:one)), new_family_person_path(families(:one)),
      person_path(people(:smith_dad)), edit_person_path(people(:smith_dad))
    ].each do |path|
      get path
      assert_redirected_to new_family_session_path, "GET #{path}"
    end

    assert_no_difference "Person.count" do
      post family_people_path(families(:one)), params: valid_person_params
      patch person_path(people(:smith_dad)), params: { person: { first_name: "X" } }
      delete person_path(people(:smith_dad))
    end
    assert_equal "Sam", people(:smith_dad).reload.first_name
  end

  # --- non-admin: read only, own family only ---

  test "non-admin sees their own family's people, with no controls" do
    sign_in_as "examplefamily"

    get family_people_path(families(:one))
    assert_response :success
    assert_select "a", "Sam Smith"
    assert_select "a", "Lily Smith"
    assert_select "span", "Lion"
    assert_select "a", text: "Add person", count: 0
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
    assert_select "a", text: "Ben Jones", count: 0

    get person_path(people(:smith_lion))
    assert_response :success
    assert_match "Lily Smith", response.body
    assert_select "a", text: "Edit", count: 0
    assert_select "button", text: "Delete", count: 0
  end

  test "non-admin cannot see another family's people" do
    sign_in_as "examplefamily"

    get family_people_path(families(:two))
    assert_denied

    get person_path(people(:jones_bear))
    assert_denied
  end

  test "non-admin cannot add, edit or delete anyone's people" do
    sign_in_as "examplefamily"

    [ families(:one), families(:two) ].each do |family|
      get new_family_person_path(family)
      assert_denied
    end
    [ people(:smith_dad), people(:jones_bear) ].each do |person|
      get edit_person_path(person)
      assert_denied
    end

    assert_no_difference "Person.count" do
      post family_people_path(families(:one)), params: valid_person_params
      assert_denied
      post family_people_path(families(:two)), params: valid_person_params
      assert_denied
      delete person_path(people(:smith_dad))
      assert_denied
      delete person_path(people(:jones_bear))
      assert_denied
    end

    patch person_path(people(:smith_dad)), params: { person: { first_name: "Changed" } }
    assert_denied
    assert_equal "Sam", people(:smith_dad).reload.first_name
  end

  test "family page links to people only for the own family" do
    sign_in_as "examplefamily"

    get family_path(families(:one))
    assert_select "a[href=?]", family_people_path(families(:one)), text: "People (2)"

    get family_path(families(:two))
    assert_response :success
    assert_select "a[href=?]", family_people_path(families(:two)), count: 0
    assert_no_match "People (", response.body
  end

  # --- admin: everything, for any family ---

  test "admin sees and links to any family's people with all controls" do
    sign_in_as "adminfamily"

    get family_path(families(:two))
    assert_select "a[href=?]", family_people_path(families(:two)), text: "People (1)"

    get family_people_path(families(:two))
    assert_response :success
    assert_select "a", "Ben Jones"
    assert_select "a", text: "Add person", count: 1
    assert_select "a[href=?]", edit_person_path(people(:jones_bear)), text: "Edit"
    assert_select "form[action=?] button", person_path(people(:jones_bear)), text: "Delete"
  end

  test "admin adds a person to any family" do
    sign_in_as "adminfamily"

    get new_family_person_path(families(:two))
    assert_response :success
    assert_select "select[name=?] option", "person[position]", count: 9 # prompt + 8 positions
    assert_select "option", "AOL"

    assert_difference -> { families(:two).people.count }, 1 do
      post family_people_path(families(:two)), params: valid_person_params
    end
    assert_redirected_to family_people_path(families(:two))
    person = families(:two).people.find_by!(first_name: "Newt")
    assert_equal "Smith", person.last_name
    assert person.tiger?
  end

  test "admin edits and deletes a person in any family" do
    sign_in_as "adminfamily"

    get edit_person_path(people(:jones_bear))
    assert_response :success
    assert_select "option[selected][value=bear]"

    patch person_path(people(:jones_bear)), params: { person: { first_name: "Benny", position: "webelos" } }
    assert_redirected_to family_people_path(families(:two))
    people(:jones_bear).reload
    assert_equal "Benny", people(:jones_bear).first_name
    assert people(:jones_bear).webelos?

    assert_difference "Person.count", -1 do
      delete person_path(people(:jones_bear))
    end
    assert_redirected_to family_people_path(families(:two))
    assert_response :see_other
  end

  test "the family cannot be reassigned through params" do
    sign_in_as "adminfamily"

    patch person_path(people(:jones_bear)), params: { person: { family_id: families(:one).id, first_name: "Ben" } }
    assert_equal families(:two), people(:jones_bear).reload.family
  end

  test "invalid input re-renders the form" do
    sign_in_as "adminfamily"

    assert_no_difference "Person.count" do
      post family_people_path(families(:one)), params: { person: { first_name: "", last_name: "Smith", position: "" } }
    end
    assert_response :unprocessable_entity
    assert_select "#error_explanation"

    assert_no_difference "Person.count" do
      post family_people_path(families(:one)), params: { person: { first_name: "A", last_name: "B", position: "dragon" } }
    end
    assert_response :unprocessable_entity

    patch person_path(people(:smith_dad)), params: { person: { last_name: "" } }
    assert_response :unprocessable_entity
    assert_equal "Smith", people(:smith_dad).reload.last_name
  end

  test "deleting a family through the app removes its people" do
    sign_in_as "adminfamily"

    assert_difference "Person.count", -2 do
      delete family_path(families(:one))
    end
  end

  # --- position badges ---

  test "the person page heading shows their position" do
    sign_in_as "examplefamily"

    get person_path(people(:smith_lion))
    assert_select "h2", text: /Lily Smith\s*Lion/ do
      assert_select "span.rounded-full", text: "Lion"
    end
    assert_select "dt", "Position"
  end

  test "the people list shows one position badge per person" do
    sign_in_as "examplefamily"

    get family_people_path(families(:one))
    assert_select "li", 2
    assert_select "li span.rounded-full", 2
    assert_select "li", text: /Sam Smith\s*Adult/
    assert_select "li", text: /Lily Smith\s*Lion/
  end
end
