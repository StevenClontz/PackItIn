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

  test "normalize_address keeps only lowercase letters and digits" do
    assert_equal "100mainst", Family.normalize_address("  100 Main St.  ")
    assert_equal "", Family.normalize_address("-- !!")
    assert_equal "", Family.normalize_address(nil)
  end

  test "street address matching ignores case, spacing and punctuation" do
    family = families(:one) # 100 Main St
    [ "100 Main St", "100 main st.", "100-MAIN   ST", "1 0 0 m a i n s t" ].each do |input|
      assert family.street_address_matches?(input), input
    end
  end

  test "street address matching rejects different or blank input" do
    family = families(:one)
    [ "100 Main Street", "101 Main St", "Main St", "", nil, "  ..  " ].each do |input|
      assert_not family.street_address_matches?(input), input.inspect
    end
  end

  test "a punctuation-only street address never matches" do
    family = build_family(street_address: "---")
    assert_not family.street_address_matches?("")
    assert_not family.street_address_matches?("--")
  end

  test "non_admin excludes admin families" do
    assert_equal [ "examplefamily", "joneses" ], Family.non_admin.order(:username).pluck(:username)
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
end
