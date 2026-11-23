# Preview at http://localhost:3000/rails/mailers/event_mailer (uses the development sample data).
class EventMailerPreview < ActionMailer::Preview
  def announcement
    EventMailer.with(person: adult, event: Event.upcoming.first, note: "Sign-ups are filling fast!").announcement
  end

  def rsvp_reminder
    EventMailer.with(person: adult, event: Event.upcoming.first).rsvp_reminder
  end

  def payment_reminder
    event = Event.joins(:rsvp_options).where.not(rsvp_options: { cost_cents: nil }).first || Event.first
    EventMailer.with(person: adult, event:).payment_reminder
  end

  private

  def adult
    Person.where(den: :adult).where.not(email: nil).first || Person.where(den: :adult).first
  end
end
