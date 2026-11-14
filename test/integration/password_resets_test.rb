require "test_helper"

class PasswordResetsTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  test "the log in page links to password reset" do
    get new_family_session_path
    assert_select "a[href=?]", new_family_password_path
  end

  test "requesting a reset by username emails the family's adults" do
    assert_enqueued_emails 1 do
      post family_password_path, params: { family: { login: "examplefamily" } }
    end
    assert_redirected_to new_family_session_path

    perform_enqueued_jobs
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "sam@example.com" ], mail.to
    assert_match "examplefamily", mail.text_part.body.to_s
    assert_not_nil families(:one).reload.reset_password_token
  end

  test "requesting a reset by an adult's email or phone works too" do
    [ "SAM@example.com", "(512) 555-1234" ].each do |login|
      assert_enqueued_emails 1 do
        post family_password_path, params: { family: { login: login } }
      end
    end
  end

  test "unknown accounts and families without an email get the same response and no mail" do
    [ "nobody", "joneses" ].each do |login|
      assert_no_enqueued_emails do
        post family_password_path, params: { family: { login: login } }
      end
      assert_redirected_to new_family_session_path
      follow_redirect!
      assert_match "If that account has an adult with an email address", response.body
    end
  end

  test "youth email addresses never receive account mail" do
    people(:smith_lion).update!(email: "lily@example.com")
    assert_equal [ "sam@example.com" ], families(:one).email_addresses
  end

  test "the emailed link sets a new password and signs the family in" do
    token = families(:one).send_reset_password_instructions

    get edit_family_password_path(reset_password_token: token)
    assert_response :success

    put family_password_path, params: { family: { reset_password_token: token, password: "newpassword456", password_confirmation: "newpassword456" } }
    assert_redirected_to root_path
    assert families(:one).reload.valid_password?("newpassword456")

    # The token is single use.
    delete destroy_family_session_path
    put family_password_path, params: { family: { reset_password_token: token, password: "another789", password_confirmation: "another789" } }
    assert_response :unprocessable_content
    assert families(:one).reload.valid_password?("newpassword456")
  end

  test "an expired link doesn't work" do
    token = families(:one).send_reset_password_instructions
    travel Devise.reset_password_within + 1.minute do
      put family_password_path, params: { family: { reset_password_token: token, password: "newpassword456", password_confirmation: "newpassword456" } }
      assert_response :unprocessable_content
    end
    assert families(:one).reload.valid_password?("password123")
  end
end
