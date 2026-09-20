class EventsController < ApplicationController
  before_action :authenticate_family!
  load_and_authorize_resource

  def index
    @upcoming = @events.upcoming
    @past = @events.past
  end

  def show
    @people = current_family.people.order(:last_name, :first_name)
    @rsvps = @event.rsvps.where(person: @people).index_by(&:person_id)

    if current_family.admin?
      @everyone = Person.includes(:family).order(:last_name, :first_name)
      @responses = @event.rsvps.index_by(&:person_id)
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
    @event.destroy!
    redirect_to events_path, notice: "Event deleted.", status: :see_other
  end

  private

  def event_params
    params.expect(event: %i[title description starts_at ends_at rsvp_deadline_at])
  end
end
