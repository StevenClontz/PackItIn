require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  test "home page is public" do
    get root_path
    assert_response :success
    assert_select "a", "Log in"
  end

  # --- only admins create families: there is no sign-up ---

  test "home page has no sign up link" do
    get root_path
    assert_select "a", text: /sign up/i, count: 0
  end

  test "sign up routes do not exist" do
    assert_no_difference "Family.count" do
      get "/account/sign_up"
      assert_response :not_found

      post "/account", params: { family: { username: "brandnew", password: "password123", password_confirmation: "password123", **profile_params } }
      assert_response :not_found

      get "/account/cancel"
      assert_response :not_found
    end
  end

  test "sign in page has no sign up link" do
    get new_family_session_path
    assert_select "a", text: /sign up/i, count: 0
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

  # --- sign in with family + street address ---

  def sign_in_with_address(family, street_address)
    post address_family_session_path, params: { address_sign_in: { family_id: family.id, street_address: street_address } }
  end

  def assert_address_sign_in_rejected
    assert_response :unprocessable_entity
    assert_select "p", "Family info not recognized."
    get families_path
    assert_redirected_to new_family_session_path, "should not be signed in"
  end

  test "sign in page lists non-admin families only and still has the username form" do
    get new_family_session_path
    assert_response :success
    assert_select "select[name=?] option", "address_sign_in[family_id]", text: "The Example Family"
    assert_select "select[name=?] option", "address_sign_in[family_id]", text: "The Joneses"
    assert_select "select[name=?] option", "address_sign_in[family_id]", text: "Pack Administrators", count: 0
    assert_select "input[name=?]", "address_sign_in[street_address]"
    assert_select "input[name=?]", "family[username]"
    assert_select "input[name=?]", "family[password]"
  end

  test "sign in by choosing a family and entering its address" do
    sign_in_with_address families(:one), "100 Main St"
    assert_redirected_to root_path
    follow_redirect!
    assert_match "examplefamily", response.body

    get families_path
    assert_response :success
  end

  test "address sign in ignores case, spacing and punctuation" do
    sign_in_with_address families(:one), "  100, MAIN st. "
    assert_redirected_to root_path
  end

  test "address sign in can be followed by sign out" do
    sign_in_with_address families(:two), "22 elm ave"
    delete destroy_family_session_path
    assert_redirected_to root_path
    get families_path
    assert_redirected_to new_family_session_path
  end

  test "address sign in rejects a wrong or blank address" do
    [ "101 Main St", "100 Main Street", "", "!!!" ].each do |address|
      sign_in_with_address families(:one), address
      assert_address_sign_in_rejected
    end
  end

  test "address sign in rejects another family's address" do
    sign_in_with_address families(:one), families(:two).street_address
    assert_address_sign_in_rejected
  end

  test "address sign in rejects a missing or unknown family" do
    post address_family_session_path, params: { address_sign_in: { street_address: "100 Main St" } }
    assert_address_sign_in_rejected

    post address_family_session_path, params: { address_sign_in: { family_id: 0, street_address: "100 Main St" } }
    assert_address_sign_in_rejected

    post address_family_session_path
    assert_address_sign_in_rejected
  end

  test "admin families cannot sign in with an address, even with a forged id" do
    sign_in_with_address families(:admin), families(:admin).street_address
    assert_address_sign_in_rejected
  end

  test "a family that opted into password-only login is excluded from the sign in page's family list" do
    families(:one).update!(password_only: true)
    get new_family_session_path
    assert_select "select[name=?] option", "address_sign_in[family_id]", text: "The Example Family", count: 0
    assert_select "select[name=?] option", "address_sign_in[family_id]", text: "The Joneses"
  end

  test "a family that opted into password-only login cannot sign in with an address, even with a forged id" do
    families(:one).update!(password_only: true)
    sign_in_with_address families(:one), families(:one).street_address
    assert_address_sign_in_rejected
  end

  test "failed address sign in keeps the chosen family selected" do
    sign_in_with_address families(:two), "wrong"
    assert_select "select[name=?] option[selected][value=?]", "address_sign_in[family_id]", families(:two).id.to_s
  end

  test "signed-in families are redirected away from address sign in" do
    post family_session_path, params: { family: { username: "examplefamily", password: "password123" } }
    sign_in_with_address families(:two), "22 Elm Ave"
    assert_redirected_to root_path

    follow_redirect!
    assert_select "strong", "examplefamily"
  end

  test "address sign in is rate limited per IP" do
    # Tests use a null cache store, which never counts; pretend this IP is already over the limit.
    store = ActionController::Base.cache_store
    store.define_singleton_method(:increment) { |*| 11 }
    begin
      sign_in_with_address families(:one), "100 Main St"
    ensure
      store.singleton_class.remove_method(:increment)
    end

    assert_redirected_to new_family_session_path
    follow_redirect!
    assert_select "p", /Too many attempts/
    get families_path
    assert_redirected_to new_family_session_path, "a rate-limited attempt must not sign in"
  end

  test "username sign in is case insensitive" do
    post family_session_path, params: { family: { username: "ExampleFamily", password: "password123" } }
    assert_redirected_to root_path
  end

  test "wrong password is rejected" do
    post family_session_path, params: { family: { username: "examplefamily", password: "nope" } }
    assert_response :unprocessable_entity
  end

  # Families are created and edited through FamiliesController; Devise only signs in and out.
  test "there are no Devise routes to edit or delete an account" do
    assert_no_difference "Family.count" do
      [ nil, "examplefamily", "adminfamily" ].each do |username|
        post family_session_path, params: { family: { username: username, password: "password123" } } if username

        get "/account/edit"
        assert_response :not_found, "GET /account/edit as #{username.inspect}"
        [ :patch, :put, :delete ].each do |verb|
          public_send(verb, "/account", params: { family: { name: "Hijacked" } })
          assert_response :not_found, "#{verb.upcase} /account as #{username.inspect}"
        end
        assert_equal "The Example Family", families(:one).reload.name

        delete destroy_family_session_path if username
      end
    end
  end
end
