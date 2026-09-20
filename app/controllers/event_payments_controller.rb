# A family paying for what its RSVPs cost, from its Scout Account into the event's account.
class EventPaymentsController < ApplicationController
  before_action :authenticate_family!
  before_action :set_event

  # POST /events/:event_id/payment with amount_cents (what the family was shown). Always the signed-in family.
  def create
    authorize! :pay, @event
    expected = params[:amount_cents].to_i

    case EventPayment.new(event: @event, family: current_family).pay(expected_cents: expected)
    when :paid then redirect_to @event, notice: "Paid #{Money.new(expected).format} for #{@event.title}.", status: :see_other
    when :not_ready then redirect_to @event, alert: "Mark everyone attending or not attending before paying.", status: :see_other
    when :nothing_due then redirect_to @event, alert: "There is nothing to pay for #{@event.title}.", status: :see_other
    else redirect_to @event, alert: "The amount due changed. Please review it and try again.", status: :see_other
    end
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end
end
