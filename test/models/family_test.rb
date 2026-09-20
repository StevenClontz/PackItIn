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
end
