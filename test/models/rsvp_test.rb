require "test_helper"

class RsvpTest < ActiveSupport::TestCase
  def build_rsvp(**attrs)
    Rsvp.new({ event: events(:campout), person: people(:smith_dad), status: "attending" }.merge(attrs))
  end

  test "valid with an event, a person and a status" do
    assert build_rsvp.valid?
  end

  test "accepts attending, maybe and not_attending" do
    %w[attending maybe not_attending].each do |status|
      assert build_rsvp(status: status).valid?, status
    end
  end

  test "rejects an unknown status" do
    assert_not build_rsvp(status: "definitely").valid?
  end

  test "requires a status" do
    rsvp = build_rsvp(status: nil)
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:status], "can't be blank"
  end

  test "requires an event and a person" do
    assert_not build_rsvp(event: nil).valid?
    assert_not build_rsvp(person: nil).valid?
  end

  test "a person can only RSVP once per event" do
    duplicate = build_rsvp(event: events(:pack_meeting), person: people(:smith_dad))
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:person_id], "has already been taken"
  end

  test "the same person can RSVP to different events, and different people to the same event" do
    assert build_rsvp(event: events(:campout), person: people(:smith_dad)).valid?
    assert build_rsvp(event: events(:campout), person: people(:smith_lion)).valid?
  end

  test "labels and options are human readable" do
    assert_equal [ [ "Attending", "attending" ], [ "Maybe", "maybe" ], [ "Not attending", "not_attending" ] ], Rsvp.status_options
    assert_equal "Not attending", rsvps(:jones_bear_pack_meeting).status_label
  end

  # --- options ---

  def build_option_rsvp(**attrs)
    Rsvp.new({ event: events(:weekend_trip), person: people(:smith_dad), status: "attending", rsvp_option: rsvp_options(:full_weekend) }.merge(attrs))
  end

  test "on an event with options, attending and maybe need one" do
    %w[attending maybe].each do |status|
      rsvp = build_option_rsvp(status: status, rsvp_option: nil)
      assert_not rsvp.valid?, status
      assert_includes rsvp.errors[:rsvp_option], "must be chosen"
      assert build_option_rsvp(status: status).valid?, status
    end
  end

  test "not attending needs no option and clears any that is given" do
    rsvp = build_option_rsvp(status: "not_attending")
    assert rsvp.valid?
    assert_nil rsvp.rsvp_option

    assert build_option_rsvp(status: "not_attending", rsvp_option: nil).valid?
  end

  test "an option from another event is rejected" do
    other = RsvpOption.create!(event: events(:campout), name: "Overnight")
    rsvp = build_option_rsvp(rsvp_option: other)
    assert_not rsvp.valid?
    assert_includes rsvp.errors[:rsvp_option], "isn't an option for this event"
  end

  test "an event without options takes none" do
    assert build_rsvp.valid?, "campout has no options, so none is needed"
    assert_not build_rsvp(rsvp_option: rsvp_options(:day_trip)).valid?
  end

  test "changing to a different option is fine" do
    rsvp = rsvps(:jones_bear_weekend_trip)
    assert rsvp.update(rsvp_option: rsvp_options(:full_weekend))
  end

  test "summary combines the answer and the option" do
    assert_equal "Attending - Day trip only", rsvps(:jones_bear_weekend_trip).summary
    assert_equal "Maybe", rsvps(:smith_lion_pack_meeting).summary, "no options on this event"
    assert_equal "Not attending", rsvps(:jones_bear_pack_meeting).summary
  end

  test "an answer given before the event had options is kept, and reads as needing a choice" do
    legacy = rsvps(:smith_dad_pack_meeting)
    events(:pack_meeting).rsvp_options.create!(name: "In person")

    assert_equal "Attending - choose an option", legacy.reload.summary
    assert_not legacy.update(status: "maybe"), "changing it requires choosing an option"
  end
end
