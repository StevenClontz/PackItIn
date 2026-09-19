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

  test "no family can be destroyed, even by itself" do
    ability = Ability.new(families(:one))
    assert ability.cannot?(:destroy, families(:one))
    assert ability.cannot?(:destroy, families(:two))
    assert ability.cannot?(:destroy, Family)
  end
end
