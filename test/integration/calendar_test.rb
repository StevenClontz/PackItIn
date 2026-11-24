require "test_helper"

class CalendarTest < ActionDispatch::IntegrationTest
  test "guests can fetch the calendar feed" do
    get calendar_path

    assert_response :success
    assert_equal "text/calendar", response.media_type
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "X-WR-CALNAME:"
  end

  test "the feed lists events with stable ids and UTC times" do
    meeting = events(:pack_meeting)
    get calendar_path

    cal = Icalendar::Calendar.parse(response.body).first
    entry = cal.events.find { |e| e.uid == "event-#{meeting.id}@www.example.com" }

    assert entry, "expected the pack meeting in the feed"
    assert_equal "Pack Meeting", entry.summary
    assert_equal meeting.starts_at.to_i, entry.dtstart.to_i
    assert_equal meeting.ends_at.to_i, entry.dtend.to_i
    assert_match(/DTSTART:\d{8}T\d{6}Z/, response.body)
    assert_includes entry.description, event_url(meeting)
    assert_includes cal.events.map(&:summary), "Fall Campout"
    assert_includes cal.events.map(&:summary), "Trail Hike"
  end

  test "events that ended over a year ago are left out" do
    Event.create!(title: "Ancient Derby", starts_at: 2.years.ago, ends_at: 2.years.ago + 2.hours)
    get calendar_path

    assert_not_includes response.body, "Ancient Derby"
  end

  test "an edited event invalidates the cached feed" do
    get calendar_path
    etag = response.headers["ETag"]

    get calendar_path, headers: { "If-None-Match" => etag }
    assert_response :not_modified

    events(:pack_meeting).update!(title: "Pack Meeting (moved)")
    get calendar_path, headers: { "If-None-Match" => etag }
    assert_response :success
    assert_includes response.body, "Pack Meeting (moved)"
  end

  test "the events page offers subscribe links" do
    get events_path

    assert_select "a[href^='https://calendar.google.com/calendar/render?cid=webcal']"
    assert_select "a[href='webcal://www.example.com/calendar.ics']"
    assert_select "input[value='http://www.example.com/calendar.ics']"
  end
end
