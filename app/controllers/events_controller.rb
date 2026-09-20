class EventsController < ApplicationController
  before_action :authenticate_family!
  load_and_authorize_resource

  def index
    @upcoming = @events.upcoming
    @past = @events.past
  end

  def show
    @options = @event.rsvp_options.to_a
    @people = current_family.people.order(:last_name, :first_name)
    @rsvps = @event.rsvps.where(person: @people).includes(:rsvp_option).index_by(&:person_id)
    @payment = EventPayment.new(event: @event, family: current_family)

    if current_family.admin?
      @everyone = Person.includes(:family).order(:last_name, :first_name)
      @responses = @event.rsvps.includes(:rsvp_option).index_by(&:person_id)
    end
  end

  def new
  end

  def create
    if @event.save
      redirect_to @event, notice: "Event created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      redirect_to @event, notice: "Event updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @event.destroy
      redirect_to events_path, notice: "Event deleted.", status: :see_other
    else
      redirect_to @event, alert: @event.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def event_params
    params.expect(event: %i[title description starts_at ends_at rsvp_deadline_at])
  end
end
