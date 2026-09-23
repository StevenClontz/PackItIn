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

  # --- the two money fields: cost, and the optional youth cost ---

  { cost: "Cost", youth_cost: "Youth cost" }.each do |field, label|
    cents = :"#{field}_cents"
    dollars = :"#{field}_dollars"

    test "#{field} is optional" do
      option = RsvpOption.new(event: events(:campout), name: "Overnight")
      assert option.valid?
      assert_nil option.public_send(field)
      assert_nil option.public_send(dollars)
    end

    test "#{field} is stored in cents and read back as money and dollars" do
      option = RsvpOption.new(event: events(:campout), name: "Overnight", dollars => "$1,250.5")
      assert option.valid?
      assert_equal 125_050, option.public_send(cents)
      assert_equal Money.new(1_250_50), option.public_send(field)

      option.save!
      assert_equal "1250.50", RsvpOption.find(option.id).public_send(dollars)
    end

    test "#{field} of zero is kept and blank clears it" do
      option = RsvpOption.new(event: events(:campout), name: "Overnight", dollars => "0")
      assert option.valid?
      assert_equal 0, option.public_send(cents)

      option.public_send(:"#{dollars}=", "")
      assert_nil option.public_send(cents)
      assert option.valid?
    end

    test "a malformed #{field} is rejected and remembered for the form" do
      [ "abc", "-5", "1.234", "1e3", "12.", "9999999999" ].each do |input|
        option = RsvpOption.new(event: events(:campout), name: "Overnight", dollars => input)
        assert_not option.valid?, input
        assert_includes option.errors.full_messages, "#{label} must be a dollar amount such as 25 or 25.50", input
        assert_equal input, option.public_send(dollars), "shows what was typed"
      end
    end

    test "a #{field} above the maximum is rejected" do
      assert RsvpOption.new(event: events(:campout), name: "A", dollars => "100000").valid?

      option = RsvpOption.new(event: events(:campout), name: "B", dollars => "100000.01")
      assert_not option.valid?
      assert_includes option.errors[dollars], "must be between $0 and $100,000"
    end

    test "a negative #{field} can't be set directly either" do
      option = RsvpOption.new(event: events(:campout), name: "Overnight", cents => -1)
      assert_not option.valid?
      assert_includes option.errors[dollars], "must be between $0 and $100,000"
    end
  end

  test "the two costs are validated independently" do
    option = RsvpOption.new(event: events(:campout), name: "Overnight", cost_dollars: "25", youth_cost_dollars: "abc")
    assert_not option.valid?
    assert_equal [ "Youth cost must be a dollar amount such as 25 or 25.50" ], option.errors.full_messages
    assert_equal 2500, option.cost_cents
  end

  # --- who pays what ---

  def option_with(cost: nil, youth_cost: nil)
    RsvpOption.new(event: events(:campout), name: "Overnight", cost_cents: cost, youth_cost_cents: youth_cost)
  end

  def person_at(den)
    Person.new(family: families(:one), first_name: "Pat", last_name: "Smith", den: den)
  end

  ADULT = :adult
  NON_ADULTS = %i[lion tiger wolf bear webelos aol other_youth].freeze

  test "with one price, everyone pays it" do
    option = option_with(cost: 2500)
    [ ADULT, *NON_ADULTS ].each { |den| assert_equal Money.new(25_00), option.cost_for(person_at(den)), den }
  end

  test "with a youth price, adults pay the cost and every other den the youth cost" do
    option = option_with(cost: 6000, youth_cost: 3000)
    assert_equal Money.new(60_00), option.cost_for(person_at(ADULT))
    NON_ADULTS.each { |den| assert_equal Money.new(30_00), option.cost_for(person_at(den)), den }
  end

  test "a youth price without a cost makes the option free for adults" do
    option = option_with(youth_cost: 3000)
    assert_equal Money.new(0), option.cost_for(person_at(ADULT))
    NON_ADULTS.each { |den| assert_equal Money.new(30_00), option.cost_for(person_at(den)), den }
  end

  test "a youth price of zero makes the option free for youth only" do
    option = option_with(cost: 6000, youth_cost: 0)
    assert_equal Money.new(60_00), option.cost_for(person_at(ADULT))
    NON_ADULTS.each { |den| assert_equal Money.new(0), option.cost_for(person_at(den)), den }
  end

  test "a youth price may be higher than the adult cost" do
    option = option_with(cost: 1000, youth_cost: 5000)
    assert_equal Money.new(10_00), option.cost_for(person_at(ADULT))
    assert_equal Money.new(50_00), option.cost_for(person_at(:wolf))
  end

  test "with no prices nobody pays" do
    option = option_with
    [ ADULT, *NON_ADULTS ].each { |den| assert_equal Money.new(0), option.cost_for(person_at(den)), den }
  end

  test "an option is costed if anyone pays for it" do
    assert_not option_with.costed?
    assert_not option_with(cost: 0).costed?
    assert_not option_with(cost: 0, youth_cost: 0).costed?
    assert option_with(cost: 100).costed?
    assert option_with(youth_cost: 100).costed?
    assert option_with(cost: 0, youth_cost: 100).costed?
  end

  test "the label shows the price for that person, or just the name if they pay nothing" do
    option = option_with(cost: 6000, youth_cost: 3000)
    assert_equal "Overnight ($60.00)", option.label_for(person_at(ADULT))
    assert_equal "Overnight ($30.00)", option.label_for(person_at(:bear))

    assert_equal "Overnight", option_with(cost: 6000, youth_cost: 0).label_for(person_at(:bear))
    assert_equal "Overnight", option_with(youth_cost: 3000).label_for(person_at(ADULT))
    assert_equal "Overnight", option_with.label_for(person_at(ADULT))
    assert_equal "Overnight ($1,250.50)", option_with(cost: 125_050).label_for(person_at(ADULT))
    assert_equal "Day trip only ($25.00)", rsvp_options(:day_trip).label_for(people(:smith_lion))
    assert_equal "Full weekend ($30.00)", rsvp_options(:full_weekend).label_for(people(:smith_lion))
    assert_equal "Full weekend ($60.00)", rsvp_options(:full_weekend).label_for(people(:smith_dad))
  end

  test "the summary describes each way of pricing an option" do
    assert_nil option_with.cost_summary
    assert_nil option_with(cost: 0).cost_summary
    assert_equal "$25.00 per person", option_with(cost: 2500).cost_summary
    assert_equal "$25.00 per person", option_with(cost: 2500, youth_cost: 2500).cost_summary, "the same price is one price"
    assert_equal "$60.00 per adult, $30.00 per youth", option_with(cost: 6000, youth_cost: 3000).cost_summary
    assert_equal "$60.00 per adult, free for youth", option_with(cost: 6000, youth_cost: 0).cost_summary
    assert_equal "free for adults, $30.00 per youth", option_with(youth_cost: 3000).cost_summary
    assert_equal "free for adults, $30.00 per youth", option_with(cost: 0, youth_cost: 3000).cost_summary
    assert_equal "$60.00 per adult, $30.00 per youth", rsvp_options(:full_weekend).cost_summary
  end
end
