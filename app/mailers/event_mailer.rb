# Pack email about events, one message per adult (EventNotifier decides who gets what). Every message
# carries that person's one-click unsubscribe link.
class EventMailer < ApplicationMailer
  include EventsHelper
  before_action { @person, @event = params.values_at(:person, :event) }
  before_action :set_unsubscribe_headers
  before_action { @payment = EventPayment.new(event: @event, family: @person.family) }

  def announcement
    @note = params[:note]
    mail to: @person.email, subject: "#{@event.title}: #{event_time_range(@event)}"
  end

  def rsvp_reminder
    mail to: @person.email, subject: "Reminder: RSVP for #{@event.title} by #{format_event_time(@event.rsvp_closes_at)}"
  end

  def payment_reminder
    mail to: @person.email, subject: "Reminder: #{@payment.outstanding.format} due for #{@event.title}"
  end

  private

  def set_unsubscribe_headers
    @unsubscribe_url = unsubscribe_url(token: @person.generate_token_for(:unsubscribe))
    headers["List-Unsubscribe"] = "<#{@unsubscribe_url}>"
    headers["List-Unsubscribe-Post"] = "List-Unsubscribe=One-Click"
  end
end
