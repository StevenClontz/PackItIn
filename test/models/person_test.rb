require "test_helper"

class PersonTest < ActiveSupport::TestCase
  def build_person(**attrs)
    Person.new({ family: families(:one), first_name: "Pat", last_name: "Smith", den: :wolf }.merge(attrs))
  end

  test "valid with a family, names and a den" do
    assert build_person.valid?
  end

  test "requires first name, last name and den" do
    %i[first_name last_name den].each do |attr|
      person = build_person(attr => nil)
      assert_not person.valid?, "#{attr} should be required"
      assert_includes person.errors[attr], "can't be blank"
    end
  end

  test "requires a family" do
    assert_not build_person(family: nil).valid?
  end

  test "den enum maps to the documented integers" do
    assert_equal(
      { "adult" => 0, "lion" => 1, "tiger" => 2, "wolf" => 3, "bear" => 4, "webelos" => 5, "aol" => 6, "other_youth" => 7 },
      Person.dens
    )
  end

  test "den can be set by name or integer" do
    assert_equal "aol", build_person(den: 6).den
    assert build_person(den: "other_youth").other_youth?
    assert build_person(den: :adult).adult?
  end

  test "an unknown den is a validation error, not an exception" do
    person = build_person(den: "dragon")
    assert_nothing_raised { person.valid? }
    assert_not person.valid?
    assert person.errors[:den].any?
  end

  test "labels" do
    assert_equal "AOL", build_person(den: :aol).den_label
    assert_equal "Sam Smith", people(:smith_dad).full_name
    assert_equal [ "Adult", "Lion", "Tiger", "Wolf", "Bear", "Webelos", "AOL", "Other Youth" ], Person.den_options.map(&:first)
    assert_equal Person.dens.keys, Person.den_options.map(&:last)
  end

  test "family_dens lists the regular dens present among an adult's family, in den order" do
    assert_equal [ "lion" ], people(:smith_dad).family_dens

    families(:one).people.create!(first_name: "Wes", last_name: "Smith", den: :bear)
    assert_equal [ "lion", "bear" ], people(:smith_dad).reload.family_dens
  end

  test "family_dens excludes other_youth and is empty with no regular-den family members" do
    solo_adult = families(:admin).people.create!(first_name: "Ada", last_name: "Admin", den: :adult)
    assert_equal [], solo_adult.family_dens

    families(:admin).people.create!(first_name: "Kit", last_name: "Admin", den: :other_youth)
    assert_equal [], solo_adult.reload.family_dens
  end

  test "family_dens is empty for a non-adult" do
    assert_equal [], people(:smith_lion).family_dens
  end

  test "family has many people and deleting the family deletes them" do
    assert_equal [ people(:smith_dad), people(:smith_lion) ].sort_by(&:id), families(:one).people.sort_by(&:id)

    assert_difference "Person.count", -2 do
      families(:one).destroy
    end
  end

  test "deleting a person deletes their rsvps" do
    assert_difference "Rsvp.count", -1 do
      people(:smith_dad).destroy
    end
  end

  test "deleting a family deletes its people's rsvps" do
    assert_difference "Rsvp.count", -2 do
      families(:one).destroy
    end
  end

  test "email and phone number are optional" do
    assert build_person(email: nil, phone_number: nil).valid?
    assert build_person(email: "", phone_number: "").valid?
  end

  test "email must look like an email address" do
    person = build_person(email: "not-an-email")
    assert_not person.valid?
    assert_includes person.errors[:email], "must be a valid email address"
  end

  test "email must be unique, ignoring case" do
    person = build_person(email: people(:smith_dad).email.upcase)
    assert_not person.valid?
    assert_includes person.errors[:email], "has already been taken"
  end

  test "phone number must be 10 digits" do
    person = build_person(phone_number: "555-1234")
    assert_not person.valid?
    assert_includes person.errors[:phone_number], "must be a 10-digit phone number"
  end

  test "phone number strips punctuation before validating and saving" do
    person = build_person(phone_number: "(512) 555-9999")
    assert person.valid?
    assert_equal "5125559999", person.phone_number
  end

  test "phone number must be unique" do
    person = build_person(phone_number: people(:smith_dad).phone_number)
    assert_not person.valid?
    assert_includes person.errors[:phone_number], "has already been taken"
  end
end
