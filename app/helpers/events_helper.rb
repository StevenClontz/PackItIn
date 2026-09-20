module EventsHelper
  def format_event_time(time)
    time.strftime("%a, %b %-d, %-I:%M %p %Z")
  end

  # "Sat, Oct 3, 6:00 PM to 7:30 PM CDT", or two full stamps when the event spans days.
  def event_time_range(event)
    if event.starts_at.to_date == event.ends_at.to_date
      "#{event.starts_at.strftime('%a, %b %-d, %-I:%M %p')} to #{event.ends_at.strftime('%-I:%M %p %Z')}"
    else
      "#{format_event_time(event.starts_at)} to #{format_event_time(event.ends_at)}"
    end
  end
end
