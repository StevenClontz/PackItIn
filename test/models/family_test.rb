require "test_helper"

class FamilyTest < ActiveSupport::TestCase
  def build_family(**attrs)
    Family.new({ username: "newfamily", password: "password123", password_confirmation: "password123" }.merge(attrs))
  end

  test "valid with username and password" do
    assert build_family.valid?
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
