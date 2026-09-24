require "test_helper"

class DensTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  test "guests are sent to sign in" do
    get dens_path
    assert_redirected_to new_family_session_path
  end

  test "a signed-in non-admin family can view the page" do
    sign_in_as "examplefamily"
    get dens_path
    assert_response :success
  end

  test "each regular den lists its youth and the adults who share a family with them" do
    sign_in_as "examplefamily"
    get dens_path

    assert_select "#den_lion h3", "Lion Den"
    assert_select "#den_lion li", text: /Lily Smith.*Lion.*The Example Family/
    assert_select "#den_lion li", text: /Sam Smith.*Adult \(Lion\).*The Example Family/

    assert_select "#den_bear h3", "Bear Den"
    assert_select "#den_bear li", text: /Ben Jones.*Bear.*The Joneses/
  end

  test "a den with no youth shows an empty state for both youth and adults" do
    Person.tiger.destroy_all
    sign_in_as "examplefamily"
    get dens_path

    assert_select "#den_tiger h3", "Tiger Den"
    assert_select "#den_tiger", text: /No youth in this den yet\./
    assert_select "#den_tiger", text: /No adults linked to this den yet\./
  end

  test "an adult with youth in two different dens appears under both dens' adult lists" do
    families(:one).people.create!(first_name: "Wes", last_name: "Smith", den: :wolf)
    sign_in_as "examplefamily"

    get dens_path
    assert_select "#den_lion li", text: /Sam Smith/
    assert_select "#den_wolf li", text: /Sam Smith/
  end

  test "other_youth people appear under Other Personnel, even with a sibling in a regular den" do
    families(:one).people.create!(first_name: "Robin", last_name: "Smith", den: :other_youth)
    sign_in_as "examplefamily"

    get dens_path
    assert_select "#other_personnel li", text: /Robin Smith.*Other Youth/
    assert_select "#den_lion li", text: /Robin Smith/, count: 0
  end

  test "adults whose family has no youth in a regular den appear under Other Personnel" do
    families(:admin).people.create!(first_name: "Ada", last_name: "Admin", den: :adult)
    sign_in_as "examplefamily"

    get dens_path
    assert_select "#other_personnel li", text: /Ada Admin.*Adult.*Pack Administrators/
  end
end
