require "test_helper"

class RsvpOptionTest < ActiveSupport::TestCase
  test "valid with an event and a name" do
    assert RsvpOption.new(event: events(:campout), name: "Overnight").valid?
  end

  test "description is optional" do
    assert RsvpOption.new(event: events(:campout), name: "Overnight", description: nil).valid?
  end

  test "requires a name and an event" do
    option = RsvpOption.new(event: events(:campout), name: "")
    assert_not option.valid?
    assert_includes option.errors[:name], "can't be blank"
    assert_not RsvpOption.new(name: "Overnight").valid?
  end

  test "name is unique within an event, ignoring case" do
    duplicate = RsvpOption.new(event: events(:weekend_trip), name: "FULL WEEKEND")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "the same name can be used by different events" do
    assert RsvpOption.new(event: events(:campout), name: "Full weekend").valid?
  end

  test "an event lists its options in the order they were created" do
    events(:campout).rsvp_options.create!(name: "Zebra")
    events(:campout).rsvp_options.create!(name: "Aardvark")
    assert_equal %w[Zebra Aardvark], events(:campout).rsvp_options.map(&:name)
    assert_equal [ "Day trip only", "Full weekend" ].sort, events(:weekend_trip).rsvp_options.map(&:name).sort
  end

  test "deleting an option keeps the responses but clears their choice" do
    rsvp = rsvps(:jones_bear_weekend_trip)
    assert_equal rsvp_options(:day_trip), rsvp.rsvp_option

    assert_no_difference "Rsvp.count" do
      rsvp_options(:day_trip).destroy!
    end
    rsvp.reload
    assert_nil rsvp.rsvp_option
    assert_equal "attending", rsvp.status
    assert_equal "Attending - choose an option", rsvp.summary, "the event still has another option"
  end

  test "deleting an event deletes its options and responses" do
    assert_difference({ "RsvpOption.count" => -2, "Rsvp.count" => -1 }) do
      events(:weekend_trip).destroy!
    end
  end
end
