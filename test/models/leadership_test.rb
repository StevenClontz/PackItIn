require "test_helper"

class LeadershipTest < ActiveSupport::TestCase
  test "a pack-wide role is valid without a den" do
    assert Leadership.new(person: people(:garcia_mom), role: :treasurer).valid?
  end

  test "a den role requires a den" do
    leadership = Leadership.new(person: people(:garcia_mom), role: :den_leader)
    assert_not leadership.valid?
    assert_includes leadership.errors[:den], "must be chosen for this role"

    leadership.den = :wolf
    assert leadership.valid?
  end

  test "a pack-wide role rejects a den" do
    leadership = Leadership.new(person: people(:garcia_mom), role: :treasurer, den: :wolf)
    assert_not leadership.valid?
    assert_includes leadership.errors[:den], "is only for Den Leader and Assistant Den Leader"
  end

  test "dens are limited to the regular Cub Scout dens" do
    assert_equal Person.regular_dens, Leadership.dens.keys
    assert_equal Person.dens.slice(*Person.regular_dens), Leadership.dens
    assert_not Leadership.new(person: people(:garcia_mom), role: :den_leader, den: "adult").valid?
  end

  test "youth can't hold a leadership role" do
    leadership = Leadership.new(person: people(:smith_lion), role: :committee_member)
    assert_not leadership.valid?
    assert_includes leadership.errors[:person], "must be an adult to hold a leadership role"
  end

  test "a person can't hold the same pack-wide role twice" do
    duplicate = Leadership.new(person: people(:smith_dad), role: :cubmaster)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:role], "is already held by this person"
  end

  test "a person can't lead the same den twice in the same role, but can lead another den" do
    assert_not Leadership.new(person: people(:jones_dad), role: :den_leader, den: :bear).valid?
    assert Leadership.new(person: people(:jones_dad), role: :den_leader, den: :wolf).valid?
    assert Leadership.new(person: people(:jones_dad), role: :assistant_den_leader, den: :bear).valid?
  end

  test "a person can hold several roles" do
    sam = people(:smith_dad)
    sam.leaderships.create!(role: :treasurer)
    sam.leaderships.create!(role: :den_leader, den: :lion)

    assert_equal %w[cubmaster treasurer den_leader], sam.leaderships.in_role_order.map(&:role)
  end

  test "labels name the den for den roles" do
    assert_equal "Cubmaster", leaderships(:sam_cubmaster).label
    assert_equal "Den Leader (Bear)", leaderships(:tom_bear_den_leader).label
  end

  test "role options cover every role with readable labels" do
    assert_includes Leadership.role_options, [ "Chartered Organization Representative", "chartered_org_rep" ]
    assert_equal Leadership.roles.size, Leadership.role_options.size
  end
end
