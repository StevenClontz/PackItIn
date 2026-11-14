# Decides who gets which event email and queues one message per adult (EventMailer). Only adults
# with an email address who haven't unsubscribed are emailed (Person.notifiable).
class EventNotifier
  RSVP_REMINDER_LEAD = 2.days    # before RSVPs close
  PAYMENT_REMINDER_LEAD = 3.days # before the event starts

  def self.announce(event, note: nil)
    people = Person.notifiable.includes(:family).to_a
    people.each { |person| EventMailer.with(person:, event:, note: note.presence).announcement.deliver_later }
    event.update_column(:announced_at, Time.current)
    people.size
  end

  # Run regularly (config/recurring.yml). Each event gets each reminder at most once.
  def self.send_reminders(now: Time.current)
    rsvp_reminder_events(now).each { |event| new(event).send_rsvp_reminders if claim(event, :rsvp_reminder_sent_at, now) }
    payment_reminder_events(now).each { |event| new(event).send_payment_reminders if claim(event, :payment_reminder_sent_at, now) }
  end

  # Events whose RSVPs close within the lead time and haven't closed yet.
  def self.rsvp_reminder_events(now)
    Event.where(rsvp_reminder_sent_at: nil).where(ends_at: now..).select do |event|
      event.rsvp_closes_at.between?(now, now + RSVP_REMINDER_LEAD)
    end
  end

  # Events with a cost, starting within the lead time.
  def self.payment_reminder_events(now)
    Event.where(payment_reminder_sent_at: nil, starts_at: now..(now + PAYMENT_REMINDER_LEAD))
         .select { |event| event.rsvp_options.any?(&:costed?) }
  end

  # Marks the reminder sent, returning false if another run already did.
  def self.claim(event, column, now)
    Event.where(id: event.id, column => nil).update_all(column => now) == 1
  end

  attr_reader :event

  def initialize(event)
    @event = event
  end

  # Families with someone who hasn't answered (or said maybe).
  def send_rsvp_reminders
    deliver(:rsvp_reminder) { |payment| payment.blockers.any? }
  end

  # Families who owe money for what they RSVPed.
  def send_payment_reminders
    deliver(:payment_reminder) { |payment| payment.outstanding.positive? }
  end

  private

  def deliver(email)
    Family.where(id: Person.notifiable.select(:family_id)).includes(:people).find_each do |family|
      next unless yield EventPayment.new(event:, family:)

      family.people.select(&:notifiable?).each do |person|
        EventMailer.with(person:, event:).public_send(email).deliver_later
      end
    end
  end
end
