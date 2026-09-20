class RsvpsController < ApplicationController
  before_action :authenticate_family!
  before_action :set_event
  before_action :require_open_rsvps

  # PATCH /events/:event_id/rsvp with rsvps[<person_id>][status] and rsvps[<person_id>][rsvp_option_id].
  # People without a status are skipped. All-or-nothing.
  def update
    responses = params[:rsvps].respond_to?(:to_unsafe_h) ? params[:rsvps].to_unsafe_h : {}
    # A value that isn't a { status:, rsvp_option_id: } hash can only come from a hand-built request.
    return redirect_to(@event, alert: "That response isn't valid. Nothing was saved.", status: :see_other) unless responses.values.all?(Hash)

    answered = responses.select { |_person_id, answer| answer["status"].present? }
    return redirect_to(@event, alert: "Choose a response for at least one person.", status: :see_other) if answered.empty?

    Rsvp.transaction do
      answered.each do |person_id, answer|
        rsvp = Rsvp.find_or_initialize_by(event: @event, person: Person.find(person_id))
        authorize! :update, rsvp
        rsvp.update!(status: answer["status"], rsvp_option_id: answer["rsvp_option_id"].presence)
      end
    end
    redirect_to @event, notice: "RSVPs saved.", status: :see_other
  rescue ActiveRecord::RecordInvalid => error
    redirect_to @event, alert: "#{failure_reason(error.record)} Nothing was saved.", status: :see_other
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  # The Ability enforces this too; checking here first gives families a clearer message.
  def require_open_rsvps
    return if current_family.admin? || @event.rsvp_open?

    redirect_to @event, alert: "RSVPs for this event closed #{helpers.format_event_time(@event.rsvp_closes_at)}. Ask an admin to change your response.", status: :see_other
  end

  # "Sam Smith: Rsvp option must be chosen." (or just the reason when there is no person to name).
  def failure_reason(rsvp)
    reason = "#{rsvp.errors.full_messages.to_sentence}."
    rsvp.person ? "#{rsvp.person.full_name}: #{reason}" : reason
  end
end
