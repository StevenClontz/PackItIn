# Admins emailing an event to every family (EventNotifier.announce).
class EventAnnouncementsController < ApplicationController
  before_action :authenticate_family!
  before_action :set_event
  before_action { authorize! :announce, @event }

  def new
    @recipient_count = Person.notifiable.count
  end

  def create
    count = EventNotifier.announce(@event, note: params[:note])
    redirect_to @event, notice: "Announcement emailed to #{helpers.pluralize(count, 'adult')}.", status: :see_other
  end

  private

  def set_event
    @event = Event.find(params[:event_id])
  end
end
