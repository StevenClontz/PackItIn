require "test_helper"

class PersonTest < ActiveSupport::TestCase
  def build_person(**attrs)
    Person.new({ family: families(:one), first_name: "Pat", last_name: "Smith", position: :wolf }.merge(attrs))
  end

  test "valid with a family, names and a position" do
    assert build_person.valid?
  end

  test "requires first name, last name and position" do
    %i[first_name last_name position].each do |attr|
      person = build_person(attr => nil)
      assert_not person.valid?, "#{attr} should be required"
      assert_includes person.errors[attr], "can't be blank"
    end
  end

  test "requires a family" do
    assert_not build_person(family: nil).valid?
  end

  test "position enum maps to the documented integers" do
    assert_equal(
      { "adult" => 0, "lion" => 1, "tiger" => 2, "wolf" => 3, "bear" => 4, "webelos" => 5, "aol" => 6, "youth" => 7 },
      Person.positions
    )
  end

  test "position can be set by name or integer" do
    assert_equal "aol", build_person(position: 6).position
    assert build_person(position: "youth").youth?
    assert build_person(position: :adult).adult?
  end

  test "an unknown position is a validation error, not an exception" do
    person = build_person(position: "dragon")
    assert_nothing_raised { person.valid? }
    assert_not person.valid?
    assert person.errors[:position].any?
  end

  test "labels" do
    assert_equal "AOL", build_person(position: :aol).position_label
    assert_equal "Sam Smith", people(:smith_dad).full_name
    assert_equal %w[Adult Lion Tiger Wolf Bear Webelos AOL Youth], Person.position_options.map(&:first)
    assert_equal Person.positions.keys, Person.position_options.map(&:last)
  end

  test "family has many people and deleting the family deletes them" do
    assert_equal [ people(:smith_dad), people(:smith_lion) ].sort_by(&:id), families(:one).people.sort_by(&:id)

    assert_difference "Person.count", -2 do
      families(:one).destroy
    end
  end
end
