require "test_helper"

class EventNotifierTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  setup do
    ActionMailer::Base.deliveries.clear
    people(:jones_dad).update!(email: "tom@example.com")
  end

  def recipients
    perform_enqueued_jobs
    ActionMailer::Base.deliveries.flat_map(&:to).sort
  end

  test "announcements go to every notifiable adult and record when they went" do
    people(:garcia_mom).update!(email: "carlos@example.com", email_opt_out: true)
    people(:smith_lion).update!(email: "lily@example.com")

    assert_equal 2, EventNotifier.announce(events(:campout), note: "Bring s'mores")
    assert_equal %w[sam@example.com tom@example.com], recipients
    assert_not_nil events(:campout).reload.announced_at

    mail = ActionMailer::Base.deliveries.first
    assert_match "Bring s'mores", mail.html_part.body.to_s
    assert_match %r{/unsubscribe/}, mail["List-Unsubscribe"].to_s
  end

  test "RSVP reminders go out once, shortly before RSVPs close, to families still missing answers" do
    event = events(:campout)
    # Smiths: no answers. Joneses: everyone answered.
    Rsvp.create!(event:, person: people(:jones_dad), status: :not_attending)
    Rsvp.create!(event:, person: people(:jones_bear), status: :attending)

    EventNotifier.send_reminders(now: event.rsvp_closes_at - 3.days)
    assert_empty recipients, "too early"

    EventNotifier.send_reminders(now: event.rsvp_closes_at - 1.day)
    assert_equal %w[sam@example.com], recipients
    assert_match "Lily Smith (no response)", ActionMailer::Base.deliveries.last.text_part.body.to_s

    ActionMailer::Base.deliveries.clear
    EventNotifier.send_reminders(now: event.rsvp_closes_at - 2.hours)
    assert_empty recipients, "sent only once"
  end

  test "payment reminders go to families who owe money shortly before the event" do
    event = events(:weekend_trip)

    EventNotifier.send_reminders(now: event.starts_at - 1.day)
    assert_equal %w[tom@example.com], recipients # Ben Jones is going on the day trip
    assert_match "$25.00 due", ActionMailer::Base.deliveries.last.subject

    # Once paid, nothing is owed.
    ActionMailer::Base.deliveries.clear
    event.update_column(:payment_reminder_sent_at, nil)
    EventPayment.new(event:, family: families(:two)).pay(expected_cents: 2500)
    EventNotifier.send_reminders(now: event.starts_at - 1.day)
    assert_not_includes recipients, "tom@example.com"
  end

  test "free events get no payment reminder" do
    assert_not_includes EventNotifier.payment_reminder_events(events(:pack_meeting).starts_at - 1.day), events(:pack_meeting)
  end
end
