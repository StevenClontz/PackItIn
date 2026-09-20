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

  test "guests have no abilities on events or rsvps" do
    ability = Ability.new(nil)
    assert ability.cannot?(:read, events(:pack_meeting))
    assert ability.cannot?(:read, Event)
    assert ability.cannot?(:update, rsvps(:smith_dad_pack_meeting))
  end

  test "non-admin family can read events but not change them" do
    ability = Ability.new(families(:one))
    assert ability.can?(:read, events(:pack_meeting))
    assert ability.can?(:read, Event)
    %i[create new update destroy].each do |action|
      assert ability.cannot?(action, events(:pack_meeting)), action
      assert ability.cannot?(action, Event.new), "new: #{action}"
    end
  end

  test "non-admin family can RSVP only its own people, and only read its own RSVPs" do
    ability = Ability.new(families(:one))
    assert ability.can?(:read, rsvps(:smith_dad_pack_meeting))
    assert ability.can?(:update, rsvps(:smith_dad_pack_meeting))
    assert ability.can?(:create, Rsvp.new(event: events(:campout), person: people(:smith_lion)))
    assert ability.can?(:update, Rsvp.new(event: events(:campout), person: people(:smith_lion)))

    assert ability.cannot?(:read, rsvps(:jones_bear_pack_meeting))
    assert ability.cannot?(:update, rsvps(:jones_bear_pack_meeting))
    assert ability.cannot?(:create, Rsvp.new(event: events(:campout), person: people(:jones_bear)))
  end

  test "non-admin family cannot destroy an RSVP" do
    assert Ability.new(families(:one)).cannot?(:destroy, rsvps(:smith_dad_pack_meeting))
  end

  test "non-admin family cannot RSVP after the default deadline (the end time)" do
    ability = Ability.new(families(:one))
    rsvp = Rsvp.new(event: events(:pack_meeting), person: people(:smith_dad))

    travel_to events(:pack_meeting).ends_at - 1.minute do
      assert ability.can?(:update, rsvps(:smith_dad_pack_meeting))
    end
    travel_to events(:pack_meeting).ends_at + 1.minute do
      assert ability.cannot?(:update, rsvps(:smith_dad_pack_meeting))
      assert ability.cannot?(:create, rsvp)
    end
    assert ability.cannot?(:update, Rsvp.new(event: events(:past_hike), person: people(:smith_dad)))
  end

  test "non-admin family cannot RSVP after an explicit earlier deadline" do
    ability = Ability.new(families(:one))
    rsvp = Rsvp.new(event: events(:campout), person: people(:smith_dad)) # deadline is 2 weeks out, event 3 weeks out

    travel_to events(:campout).rsvp_deadline_at - 1.minute do
      assert ability.can?(:create, rsvp)
    end
    travel_to events(:campout).rsvp_deadline_at + 1.minute do
      assert events(:campout).starts_at.future?, "the event itself hasn't started"
      assert ability.cannot?(:create, rsvp)
    end
  end

  test "admin family can manage events and every RSVP, even after the deadline" do
    ability = Ability.new(families(:admin))
    assert ability.can?(:manage, Event)
    assert ability.can?(:create, Event.new)
    assert ability.can?(:destroy, events(:pack_meeting))
    assert ability.can?(:update, rsvps(:jones_bear_pack_meeting))
    assert ability.can?(:create, Rsvp.new(event: events(:past_hike), person: people(:jones_bear)))
  end

  test "guests have no abilities on funds, accounts or ledger transactions" do
    ability = Ability.new(nil)
    assert ability.cannot?(:read, funds(:general))
    assert ability.cannot?(:view_account, families(:one))
    assert ability.cannot?(:create, LedgerTransaction)
  end

  test "non-admin family can view only its own money account" do
    ability = Ability.new(families(:one))
    assert ability.can?(:view_account, families(:one))
    assert ability.cannot?(:view_account, families(:two))
    assert ability.cannot?(:view_account, families(:admin))
  end

  test "non-admin family can read every fund but not change one" do
    ability = Ability.new(families(:one))
    assert ability.can?(:read, funds(:general))
    assert ability.can?(:read, Fund)
    %i[create new update destroy].each do |action|
      assert ability.cannot?(action, funds(:general)), action
      assert ability.cannot?(action, Fund.new), "new: #{action}"
    end
  end

  test "non-admin family cannot record ledger transactions" do
    ability = Ability.new(families(:one))
    assert ability.cannot?(:create, LedgerTransaction)
    assert ability.cannot?(:new, LedgerTransaction)
  end

  test "admin family can manage funds, ledger transactions and every family's account" do
    ability = Ability.new(families(:admin))
    assert ability.can?(:manage, Fund)
    assert ability.can?(:create, LedgerTransaction)
    assert ability.can?(:view_account, families(:one))
    assert ability.can?(:view_account, families(:admin))
  end

  test "non-admin family can read RSVP options but not change them" do
    ability = Ability.new(families(:one))
    assert ability.can?(:read, rsvp_options(:day_trip))
    %i[create new update destroy].each do |action|
      assert ability.cannot?(action, rsvp_options(:day_trip)), action
      assert ability.cannot?(action, RsvpOption.new(event: events(:weekend_trip))), "new: #{action}"
    end
  end

  test "guests can't see RSVP options and admins manage them" do
    assert Ability.new(nil).cannot?(:read, rsvp_options(:day_trip))
    assert Ability.new(families(:admin)).can?(:manage, RsvpOption)
  end

  test "families can pay for events, guests can't" do
    assert Ability.new(families(:one)).can?(:pay, events(:weekend_trip))
    assert Ability.new(families(:admin)).can?(:pay, events(:weekend_trip))
    assert Ability.new(nil).cannot?(:pay, events(:weekend_trip))
  end

  test "any signed-in family can read an event, and so its account" do
    assert Ability.new(families(:one)).can?(:read, events(:weekend_trip))
  end
end
