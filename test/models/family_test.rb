require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  def build_family(**attrs)
    Family.new({ username: "newfamily", password: "password123", password_confirmation: "password123", **profile_params }.merge(attrs))
  end

  test "valid with username and password" do
    assert build_family.valid?
  end

  test "is not an admin by default" do
    assert_not build_family.admin?
    assert_not families(:one).admin?
    assert families(:admin).admin?
  end

  test "requires a username" do
    family = build_family(username: nil)
    assert_not family.valid?
    assert_includes family.errors[:username], "can't be blank"
  end

  test "username must be unique, ignoring case" do
    family = build_family(username: families(:one).username.upcase)
    assert_not family.valid?
    assert_includes family.errors[:username], "has already been taken"
  end

  test "username rejects invalid characters" do
    assert_not build_family(username: "bad name!").valid?
  end

  %i[name street_address city state zip].each do |attribute|
    test "requires #{attribute}" do
      family = build_family(attribute => nil)
      assert_not family.valid?
      assert_includes family.errors[attribute], "can't be blank"
    end
  end

  test "zip accepts 5 digits or ZIP+4" do
    [ "12345", "12345-6789" ].each { |zip| assert build_family(zip: zip).valid?, zip }
  end

  test "zip rejects other formats" do
    [ "1234", "abcde", "123456", "12345-678" ].each do |zip|
      family = build_family(zip: zip)
      assert_not family.valid?, zip
      assert_includes family.errors[:zip], "must be a 5-digit ZIP or ZIP+4"
    end
  end

  test "state must be a known state" do
    assert_not build_family(state: "zz").valid?
    assert build_family(state: "dc").valid?
  end

  test "state options cover the 50 states and DC with readable labels" do
    options = Family.state_options
    assert_equal 51, options.size
    assert_includes options, [ "Oregon", "or" ]
    assert_includes options, [ "District of Columbia", "dc" ]
    assert_equal "Texas", families(:one).state_label
  end

  test "non_admin excludes admin families" do
    assert_equal [ "andersons", "chens", "examplefamily", "garcias", "joneses", "kims", "nguyens", "okafors", "patels", "riveras" ],
                 Family.non_admin.order(:username).pluck(:username)
  end

  test "requires a password on create" do
    assert_not build_family(password: nil, password_confirmation: nil).valid?
  end

  test "password must be long enough" do
    assert_not build_family(password: "short", password_confirmation: "short").valid?
  end

  test "password must match confirmation" do
    assert_not build_family(password_confirmation: "different123").valid?
  end

  test "existing family can be updated without a password" do
    family = families(:one)
    assert family.update(username: "renamed")
  end

  test "authenticates with the right password only" do
    family = families(:one)
    assert family.valid_password?("password123")
    assert_not family.valid_password?("wrong")
  end

  test "a family has its own ledger account, starting at zero" do
    assert_equal Money.new(0), families(:one).balance
    assert_not families(:one).ledger_activity?
    assert_equal Money.new(0), build_family.balance, "an unsaved family has no account yet"
  end

  test "a family's balance and lines follow the ledger, separately from other families" do
    transact from: :outside, to: families(:one), dollars: 40
    transact from: families(:one), to: families(:two), dollars: 15

    assert_equal Money.new(25_00), families(:one).balance
    assert_equal Money.new(15_00), families(:two).balance
    assert_equal [ Money.new(-15_00), Money.new(40_00) ], families(:one).ledger_lines.map(&:amount), "newest first"
    assert_equal [ Money.new(15_00) ], families(:two).ledger_lines.map(&:amount)
  end

  test "a family with account activity can't be destroyed, and keeps its people" do
    transact from: :outside, to: families(:one), dollars: 10

    assert_no_difference [ "Family.count", "Person.count" ] do
      assert_not families(:one).destroy
    end
    assert_includes families(:one).errors.full_messages, "The Example Family has Scout Account activity and can't be deleted"
  end

  test "activity on the other side of a transfer also protects the account" do
    transact from: families(:one), to: families(:two), dollars: 1

    assert_not families(:two).destroy
    assert_not families(:one).destroy
  end

  # --- emailed sign-in codes ---

  test "email_login_eligible lists families with an adult email address" do
    assert_equal [ "examplefamily" ], Family.email_login_eligible.pluck(:username)

    people(:jones_bear).update!(email: "ben@example.com")
    assert_equal [ "examplefamily" ], Family.email_login_eligible.pluck(:username), "a youth email doesn't count"

    people(:jones_dad).update!(email: "tom@example.com")
    assert_equal [ "examplefamily", "joneses" ], Family.email_login_eligible.order(:username).pluck(:username)
  end

  test "a login code is 6 digits, stored only as a digest, and works once" do
    family = families(:one)
    code = family.start_email_login!

    assert_match(/\A\d{6}\z/, code)
    assert_not_equal code, family.reload.login_code_digest
    assert family.verify_login_code(code)
    assert_not family.reload.verify_login_code(code)
  end

  test "a login code tolerates spaces and dashes" do
    family = families(:one)
    code = family.start_email_login!
    assert family.verify_login_code(" #{code[0, 3]}-#{code[3, 3]} ")
  end

  test "five wrong login codes use the code up" do
    family = families(:one)
    code = family.start_email_login!
    wrong = code == "000000" ? "111111" : "000000"

    5.times { assert_not family.verify_login_code(wrong) }
    assert_not family.verify_login_code(code)
  end

  test "a login code expires" do
    family = families(:one)
    code = family.start_email_login!
    travel Family::LOGIN_CODE_TTL + 1.second do
      assert_not family.verify_login_code(code)
    end
  end

  test "a new login code replaces the old code and link" do
    family = families(:one)
    old_code = family.start_email_login!
    old_token = family.generate_token_for(:email_login)
    assert_equal family, Family.find_by_token_for(:email_login, old_token)

    travel 1.second
    new_code = family.start_email_login!
    assert_nil Family.find_by_token_for(:email_login, old_token)
    assert_not family.verify_login_code(old_code) unless old_code == new_code
    assert_equal family, Family.find_by_token_for(:email_login, family.generate_token_for(:email_login))
  end
end
