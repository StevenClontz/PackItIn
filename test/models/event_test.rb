require "test_helper"

class EventTest < ActiveSupport::TestCase
  def build_event(**attrs)
    Event.new({ title: "Cookout", starts_at: 1.day.from_now, ends_at: 1.day.from_now + 2.hours }.merge(attrs))
  end

  test "valid with a title and start and end times" do
    assert build_event.valid?
  end

  test "description and rsvp deadline are optional" do
    event = build_event(description: nil, rsvp_deadline_at: nil)
    assert event.valid?
  end

  %i[title starts_at ends_at].each do |attribute|
    test "requires #{attribute}" do
      event = build_event(attribute => nil)
      assert_not event.valid?
      assert_includes event.errors[attribute], "can't be blank"
    end
  end

  test "must end after it starts" do
    start = 1.day.from_now
    [ start, start - 1.hour ].each do |finish|
      event = build_event(starts_at: start, ends_at: finish)
      assert_not event.valid?
      assert_includes event.errors[:ends_at], "must be after the start time"
    end
  end

  test "times use Central Time" do
    assert_equal "Central Time (US & Canada)", Time.zone.name
    event = build_event(starts_at: "2026-10-03T18:00", ends_at: "2026-10-03T19:30")
    assert_equal Time.utc(2026, 10, 3, 23, 0), event.starts_at.utc # CDT is UTC-5
  end

  test "fixture times are relative to now, in Central Time" do
    assert_equal 18, events(:pack_meeting).starts_at.hour
    assert events(:pack_meeting).starts_at.future?
    assert events(:past_hike).ends_at.past?
  end

  test "rsvp_closes_at defaults to the end time and honors an explicit deadline" do
    event = build_event
    assert_equal event.ends_at, event.rsvp_closes_at

    deadline = event.starts_at - 1.day
    event.rsvp_deadline_at = deadline
    assert_equal deadline, event.rsvp_closes_at
  end

  test "rsvps are open until the deadline" do
    event = build_event(starts_at: Time.zone.local(2026, 10, 3, 18), ends_at: Time.zone.local(2026, 10, 3, 19))

    travel_to Time.zone.local(2026, 10, 3, 18, 59) do
      assert event.rsvp_open?
    end
    travel_to Time.zone.local(2026, 10, 3, 19, 1) do
      assert_not event.rsvp_open?
    end

    event.rsvp_deadline_at = Time.zone.local(2026, 10, 1, 12)
    travel_to Time.zone.local(2026, 10, 1, 11, 59) do
      assert event.rsvp_open?
    end
    travel_to Time.zone.local(2026, 10, 1, 12, 1) do
      assert_not event.rsvp_open?
    end
  end

  test "upcoming and past scopes split on the end time" do
    assert_includes Event.upcoming, events(:pack_meeting)
    assert_includes Event.upcoming, events(:campout)
    assert_not_includes Event.upcoming, events(:past_hike)
    assert_equal [ events(:past_hike) ], Event.past.to_a

    assert_equal [ events(:pack_meeting), events(:campout), events(:weekend_trip) ], Event.upcoming.to_a, "soonest first"
  end

  test "an event in progress is still upcoming" do
    event = Event.create!(title: "Now", starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
    assert_includes Event.upcoming, event
    assert_not_includes Event.past, event
  end

  test "destroying an event destroys its rsvps" do
    assert_difference "Rsvp.count", -3 do
      events(:pack_meeting).destroy!
    end
  end
end
