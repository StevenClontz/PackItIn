# The ways to attend an event ("Day trip only", "Full weekend"). Admins manage them; families see them on the event page.
class RsvpOptionsController < ApplicationController
  before_action :authenticate_family!
  before_action :set_event
  before_action :set_rsvp_option, only: %i[edit update destroy]

  def new
    @rsvp_option = @event.rsvp_options.build
    authorize! :create, @rsvp_option
  end

  def create
    @rsvp_option = @event.rsvp_options.build(rsvp_option_params)
    authorize! :create, @rsvp_option

    if @rsvp_option.save
      redirect_to @event, notice: "Option added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! :update, @rsvp_option
  end

  def update
    authorize! :update, @rsvp_option

    if @rsvp_option.update(rsvp_option_params)
      redirect_to @event, notice: "Option updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! :destroy, @rsvp_option
    affected = @rsvp_option.rsvps.count
    @rsvp_option.destroy!

    notice = "Option deleted."
    notice += " #{helpers.pluralize(affected, 'response')} will need a new choice." if affected.positive?
    redirect_to @event, notice: notice, status: :see_other
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end

  def set_rsvp_option
    @rsvp_option = @event.rsvp_options.find(params[:id])
  end

  def rsvp_option_params
    params.expect(rsvp_option: %i[name description cost_dollars])
  end
end
