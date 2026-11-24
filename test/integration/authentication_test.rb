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
    post family_session_path, params: { family: { login: "examplefamily", password: "password123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "examplefamily", response.body

    delete destroy_family_session_path
    assert_redirected_to root_path
    follow_redirect!
    assert_select "a", "Log in"
  end

  test "a signed-in family visiting the sign-in page is redirected home" do
    post family_session_path, params: { family: { login: "examplefamily", password: "password123" } }

    get new_family_session_path
    assert_redirected_to root_path

    post family_session_path, params: { family: { login: "examplefamily", password: "password123" } }
    assert_redirected_to root_path
  end


  test "username sign in is case insensitive" do
    post family_session_path, params: { family: { login: "ExampleFamily", password: "password123" } }
    assert_redirected_to root_path
  end

  test "wrong password is rejected" do
    post family_session_path, params: { family: { login: "examplefamily", password: "nope" } }
    assert_response :unprocessable_entity
  end

  # --- sign in with a person's email or phone number ---

  test "sign in with a person's email" do
    post family_session_path, params: { family: { login: "Sam@Example.com", password: "password123" } }
    assert_redirected_to root_path
    follow_redirect!
    assert_match "examplefamily", response.body
  end

  test "sign in with a person's phone number, with or without punctuation" do
    [ "5125551234", "(512) 555-1234", "512-555-1234" ].each do |phone|
      post family_session_path, params: { family: { login: phone, password: "password123" } }
      assert_redirected_to root_path
      delete destroy_family_session_path
    end
  end

  test "sign in with a person's email resolves to that person's family, not another one" do
    post family_session_path, params: { family: { login: "sam@example.com", password: "password123" } }
    follow_redirect!
    assert_match "examplefamily", response.body
    assert_no_match "joneses", response.body
  end

  test "an identifier that matches no username, email, or phone number is rejected" do
    post family_session_path, params: { family: { login: "nobody@example.com", password: "password123" } }
    assert_response :unprocessable_entity
  end

  test "a blank identifier is rejected" do
    post family_session_path, params: { family: { login: "", password: "password123" } }
    assert_response :unprocessable_entity
  end

  # Families are created and edited through FamiliesController; Devise only signs in and out.
  test "there are no Devise routes to edit or delete an account" do
    assert_no_difference "Family.count" do
      [ nil, "examplefamily", "adminfamily" ].each do |username|
        post family_session_path, params: { family: { login: username, password: "password123" } } if username

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
