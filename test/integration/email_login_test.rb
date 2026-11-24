require "test_helper"

class EmailLoginTest < ActionDispatch::IntegrationTest
  setup { ActionMailer::Base.deliveries.clear }

  def request_code(family)
    perform_enqueued_jobs { post email_login_path, params: { family_id: family.is_a?(Family) ? family.id : family } }
  end

  def sent_mail
    ActionMailer::Base.deliveries.last
  end

  def sent_code
    sent_mail.subject[/\d{6}\z/]
  end

  def sent_link
    sent_mail.text_part.body.to_s[%r{http://\S+/account/sign_in/email/\S+}]
  end

  def assert_signed_in_as(username)
    get root_path
    assert_select "strong", username
  end

  # Checks the home page's nav, not a protected page: Devise would remember a protected page
  # and send the next sign-in there instead of home.
  def assert_not_signed_in
    get root_path
    assert_select "a", "Log in"
  end

  test "the sign-in page lists families with an adult email, plus the password form, but no address login" do
    get new_family_session_path

    assert_select "#email_login form[action=?]", email_login_path
    assert_select "#email_login select[name=family_id] option", text: "The Example Family"
    assert_select "#email_login select[name=family_id] option", text: "The Joneses", count: 0 # no adult email
    assert_select "#email_login input[name=email]", count: 0
    assert_select "input[name=?]", "family[password]"
    assert_select "[name^=address_sign_in]", count: 0
  end

  test "the old address sign-in route is gone" do
    post "/account/sign_in/address", params: { address_sign_in: { family_id: families(:one).id, street_address: "100 Main St" } }
    assert_response :not_found
  end

  test "one message with a code and a link goes to all of the family's adults, never its youth" do
    families(:one).people.create!(first_name: "Pat", last_name: "Smith", den: :adult, email: "pat@example.com")
    people(:smith_lion).update!(email: "lily@example.com")
    request_code families(:one)

    assert_redirected_to email_login_code_path
    assert_equal 1, ActionMailer::Base.deliveries.size
    assert_equal [ "pat@example.com", "sam@example.com" ], sent_mail.to.sort
    assert_match(/sign-in code: \d{6}\z/, sent_mail.subject)
    assert_includes sent_mail.text_part.body.to_s, sent_code
    assert sent_link
    assert_includes sent_mail.html_part.body.to_s, "The Example Family"
  end

  test "the code page names the family and masks where the code went" do
    request_code families(:one)
    follow_redirect!

    assert_select "strong", "The Example Family"
    assert_select "li", "s**@example.com"
    assert_no_match "sam@example.com", response.body
  end

  test "a family without an adult email, a missing family, or an unknown id is turned away" do
    [ families(:two), "", 0 ].each do |family|
      request_code family
      assert_redirected_to new_family_session_path
      follow_redirect!
      assert_select "p", "Choose your family."
    end
    assert_empty ActionMailer::Base.deliveries
  end

  test "asking again within a minute doesn't send another email, but later does" do
    request_code families(:one)
    request_code families(:one)
    assert_equal 1, ActionMailer::Base.deliveries.size

    travel 2.minutes do
      request_code families(:one)
    end
    assert_equal 2, ActionMailer::Base.deliveries.size
  end

  test "the emailed code signs the family in, once" do
    request_code families(:one)
    code = sent_code

    post email_login_code_path, params: { code: code }
    assert_redirected_to root_path
    assert_signed_in_as "examplefamily"

    delete destroy_family_session_path
    request_code families(:one) # puts the family back in the session; the resend wait skips the mail
    post email_login_code_path, params: { code: code }
    assert_response :unprocessable_content
    assert_not_signed_in
  end

  test "a wrong code is rejected, and five misses use the code up" do
    request_code families(:one)
    code = sent_code
    wrong = code == "000000" ? "111111" : "000000"

    post email_login_code_path, params: { code: wrong }
    assert_response :unprocessable_content
    assert_select "p", "That code is wrong or has expired."
    assert_not_signed_in

    4.times { post email_login_code_path, params: { code: wrong } }
    post email_login_code_path, params: { code: code }
    assert_response :unprocessable_content
    assert_not_signed_in
  end

  test "the code page needs a family chosen in this session" do
    get email_login_code_path
    assert_redirected_to new_family_session_path

    post email_login_code_path, params: { code: "123456" }
    assert_redirected_to new_family_session_path
  end

  test "the emailed link asks for a click before signing in, then works once" do
    request_code families(:one)
    link = sent_link

    get link
    assert_response :success
    assert_select "button", "Log in as The Example Family"
    assert_not_signed_in

    post link
    assert_redirected_to root_path
    assert_signed_in_as "examplefamily"

    delete destroy_family_session_path
    get link
    assert_redirected_to new_family_session_path
    follow_redirect!
    assert_select "p", "That sign-in link has expired or was already used."
    post link
    assert_not_signed_in
  end

  test "a code and link expire after 15 minutes" do
    request_code families(:one)
    code = sent_code
    link = sent_link

    travel 16.minutes do
      post email_login_code_path, params: { code: code }
      assert_response :unprocessable_content
      get link
      assert_redirected_to new_family_session_path
    end
  end

  test "using the code also kills the link" do
    request_code families(:one)
    link = sent_link
    post email_login_code_path, params: { code: sent_code }
    delete destroy_family_session_path

    post link
    assert_redirected_to new_family_session_path
    assert_not_signed_in
  end

  test "admins can sign in by email once an adult has an address" do
    families(:admin).people.create!(first_name: "Ada", last_name: "Admin", den: :adult, email: "ada@example.com")
    request_code families(:admin)
    post email_login_code_path, params: { code: sent_code }
    assert_signed_in_as "adminfamily"
  end

  test "a signed-in family is sent home" do
    post family_session_path, params: { family: { login: "examplefamily", password: "password123" } }

    post email_login_path, params: { family_id: families(:one).id }
    assert_redirected_to root_path
    get email_login_code_path
    assert_redirected_to root_path
  end

  def with_rate_limit_exceeded
    # Tests use a null cache store, which never counts; pretend this IP is already over the limit.
    store = ActionController::Base.cache_store
    store.define_singleton_method(:increment) { |*| 100 }
    yield
  ensure
    store.singleton_class.remove_method(:increment)
  end

  test "entering codes doesn't use up the allowance for requesting them" do
    # Count for real (the test cache store never does), per key, like the dev and production stores.
    counts = Hash.new(0)
    store = ActionController::Base.cache_store
    store.define_singleton_method(:increment) { |key, amount = 1, **| counts[key] += amount }
    begin
      3.times do
        post email_login_path, params: { family_id: families(:one).id }
        assert_redirected_to email_login_code_path
        post email_login_code_path, params: { code: "wrong" }
        assert_response :unprocessable_content
      end
      post email_login_path, params: { family_id: families(:one).id }
      assert_redirected_to email_login_code_path, "4 requests are under the limit of 5, whatever the code attempts"
    ensure
      store.singleton_class.remove_method(:increment)
    end
  end

  test "requesting codes is rate limited" do
    with_rate_limit_exceeded { request_code families(:one) }
    assert_redirected_to new_family_session_path
    assert_empty ActionMailer::Base.deliveries
  end

  test "entering codes is rate limited" do
    request_code families(:one)
    with_rate_limit_exceeded { post email_login_code_path, params: { code: sent_code } }
    assert_redirected_to new_family_session_path
    follow_redirect!
    assert_select "p", /Too many attempts/
    assert_not_signed_in
  end
end
