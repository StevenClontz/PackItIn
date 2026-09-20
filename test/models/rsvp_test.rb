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
end
