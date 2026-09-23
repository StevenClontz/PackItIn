class HomeController < ApplicationController
  def index
    @upcoming_events = Event.upcoming.limit(3)
  end
end
