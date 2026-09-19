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

  test "non-admin family cannot create families" do
    ability = Ability.new(families(:one))
    assert ability.cannot?(:new, Family.new)
    assert ability.cannot?(:create, Family.new)
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

  test "guests have no abilities on people" do
    ability = Ability.new(nil)
    assert ability.cannot?(:read, people(:smith_dad))
    assert ability.cannot?(:read, Person)
  end

  test "non-admin family can read only its own people" do
    ability = Ability.new(families(:one))
    assert ability.can?(:read, people(:smith_dad))
    assert ability.can?(:read, Person.new(family: families(:one)))
    assert ability.cannot?(:read, people(:jones_bear))
    assert ability.cannot?(:read, Person.new(family: families(:two)))
  end

  test "non-admin family cannot change any person, even its own" do
    ability = Ability.new(families(:one))
    %i[create new update destroy].each do |action|
      assert ability.cannot?(action, people(:smith_dad)), "own person: #{action}"
      assert ability.cannot?(action, people(:jones_bear)), "other person: #{action}"
      assert ability.cannot?(action, Person.new(family: families(:one))), "new own person: #{action}"
    end
  end

  test "admin family can manage every person" do
    ability = Ability.new(families(:admin))
    %i[read create update destroy].each do |action|
      assert ability.can?(action, people(:smith_dad)), action
      assert ability.can?(action, people(:jones_bear)), action
    end
    assert ability.can?(:create, Person.new(family: families(:two)))
  end
end
