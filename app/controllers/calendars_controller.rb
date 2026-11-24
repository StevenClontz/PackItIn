require "icalendar"

# A public iCalendar feed of pack events. Google Calendar, Apple Calendar and Outlook
# subscribe to this URL and re-fetch it on their own schedule, so edits show up without
# families re-importing anything.
class CalendarsController < ApplicationController
  PAST_WINDOW = 1.year

  def show
    authorize! :read, Event
    events = Event.where(ends_at: PAST_WINDOW.ago..).order(:starts_at)

    expires_in 15.minutes, public: true
    # Microsecond precision: a Time in a cache key only goes to the second, so an edit
    # made in the same second as the last fetch would otherwise keep the old ETag.
    return unless stale?(etag: [ events.count, events.maximum(:updated_at)&.utc&.iso8601(6) ], public: true)

    render plain: build_calendar(events).to_ical, content_type: "text/calendar"
  end

  private

  def build_calendar(events)
    cal = Icalendar::Calendar.new
    cal.prodid = "-//#{helpers.app_name}//Events//EN"
    cal.x_wr_calname = helpers.app_name
    cal.x_wr_timezone = Time.zone.tzinfo.name
    cal.append_custom_property("REFRESH-INTERVAL;VALUE=DURATION", "PT1H")
    cal.x_published_ttl = "PT1H"

    events.each do |event|
      cal.event do |e|
        e.uid = "event-#{event.id}@#{request.host}"
        e.dtstamp = Icalendar::Values::DateTime.new(event.updated_at.utc, "tzid" => "UTC")
        e.last_modified = Icalendar::Values::DateTime.new(event.updated_at.utc, "tzid" => "UTC")
        e.dtstart = Icalendar::Values::DateTime.new(event.starts_at.utc, "tzid" => "UTC")
        e.dtend = Icalendar::Values::DateTime.new(event.ends_at.utc, "tzid" => "UTC")
        e.summary = event.title
        e.description = [ event.description.presence, event_url(event) ].compact.join("\n\n")
        e.url = event_url(event)
      end
    end
    cal
  end
end
