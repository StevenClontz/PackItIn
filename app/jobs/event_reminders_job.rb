class EventRemindersJob < ApplicationJob
  queue_as :default

  def perform
    EventNotifier.send_reminders
  end
end
