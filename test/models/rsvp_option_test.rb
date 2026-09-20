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

  # --- cost ---

  test "cost is optional" do
    option = RsvpOption.new(event: events(:campout), name: "Overnight")
    assert option.valid?
    assert_nil option.cost
    assert_not option.costed?
    assert_nil option.cost_dollars
  end

  test "cost is stored in cents and read back as money and dollars" do
    option = RsvpOption.new(event: events(:campout), name: "Overnight", cost_dollars: "$1,250.5")
    assert option.valid?
    assert_equal 125_050, option.cost_cents
    assert_equal Money.new(1_250_50), option.cost
    assert option.costed?

    option.save!
    assert_equal "1250.50", RsvpOption.find(option.id).cost_dollars
    assert_equal "Overnight ($1,250.50)", option.label
    assert_equal "Day trip only ($25.00)", rsvp_options(:day_trip).label
  end

  test "a free option's label is just its name" do
    assert_equal "Overnight", RsvpOption.new(name: "Overnight").label
    assert_equal "Overnight", RsvpOption.new(name: "Overnight", cost_cents: 0).label
  end

  test "zero is free and blank clears the cost" do
    option = RsvpOption.new(event: events(:campout), name: "Overnight", cost_dollars: "0")
    assert option.valid?
    assert_equal 0, option.cost_cents
    assert_not option.costed?

    option.cost_dollars = ""
    assert_nil option.cost_cents
    assert option.valid?
  end

  test "a malformed cost is rejected and remembered for the form" do
    [ "abc", "-5", "1.234", "1e3", "12.", "9999999999" ].each do |input|
      option = RsvpOption.new(event: events(:campout), name: "Overnight", cost_dollars: input)
      assert_not option.valid?, input
      assert_includes option.errors.full_messages, "Cost must be a dollar amount such as 25 or 25.50", input
      assert_equal input, option.cost_dollars, "shows what was typed"
    end
  end

  test "a cost above the maximum is rejected" do
    assert RsvpOption.new(event: events(:campout), name: "A", cost_dollars: "100000").valid?

    option = RsvpOption.new(event: events(:campout), name: "B", cost_dollars: "100000.01")
    assert_not option.valid?
    assert_includes option.errors[:cost_dollars], "must be between $0 and $100,000"
  end

  test "a negative cost can't be set directly either" do
    option = RsvpOption.new(event: events(:campout), name: "Overnight", cost_cents: -1)
    assert_not option.valid?
    assert_includes option.errors[:cost_dollars], "must be between $0 and $100,000"
  end
end
