class RsvpsController < ApplicationController
  before_action :authenticate_family!
  before_action :set_event
  before_action :require_open_rsvps

  # PATCH /events/:event_id/rsvp with rsvps[<person_id>]=<status>. All-or-nothing.
  def update
    responses = params[:rsvps].respond_to?(:to_unsafe_h) ? params[:rsvps].to_unsafe_h : {}
    return redirect_to(@event, alert: "Choose a response for at least one person.", status: :see_other) if responses.empty?

    Rsvp.transaction do
      responses.each do |person_id, status|
        rsvp = Rsvp.find_or_initialize_by(event: @event, person: Person.find(person_id))
        authorize! :update, rsvp
        rsvp.update!(status: status)
      end
    end
    redirect_to @event, notice: "RSVPs saved.", status: :see_other
  rescue ActiveRecord::RecordInvalid
    redirect_to @event, alert: "That isn't a valid response, so nothing was saved.", status: :see_other
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
end
