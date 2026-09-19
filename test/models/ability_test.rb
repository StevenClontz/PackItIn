require "test_helper"

class AbilityTest < ActiveSupport::TestCase
  test "guests have no abilities" do
    ability = Ability.new(nil)
    assert ability.cannot?(:read, Family)
    assert ability.cannot?(:read, families(:one))
  end

  test "signed-in family can read any family" do
    ability = Ability.new(families(:one))
    assert ability.can?(:read, families(:one))
    assert ability.can?(:read, families(:two))
  end

  test "signed-in family can update only itself" do
    ability = Ability.new(families(:one))
    assert ability.can?(:update, families(:one))
    assert ability.cannot?(:update, families(:two))
  end

  test "non-admin family cannot destroy any family, even itself" do
    ability = Ability.new(families(:one))
    assert ability.cannot?(:destroy, families(:one))
    assert ability.cannot?(:destroy, families(:two))
    assert ability.cannot?(:destroy, Family)
  end

  test "non-admin family cannot manage everything" do
    assert Ability.new(families(:one)).cannot?(:manage, :all)
  end

  test "admin family can manage everything" do
    ability = Ability.new(families(:admin))
    assert ability.can?(:manage, :all)
    assert ability.can?(:read, families(:one))
    assert ability.can?(:update, families(:one))
    assert ability.can?(:update, families(:two))
    assert ability.can?(:destroy, families(:one))
    assert ability.can?(:destroy, families(:two))
    assert ability.can?(:create, Family)
  end

  test "admin family cannot destroy itself" do
    ability = Ability.new(families(:admin))
    assert ability.cannot?(:destroy, families(:admin))
    assert ability.can?(:update, families(:admin))
    assert ability.can?(:read, families(:admin))
  end
end
