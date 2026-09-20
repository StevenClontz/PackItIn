class Rsvp < ApplicationRecord
  belongs_to :event
  belongs_to :person

  enum :status, { attending: 0, maybe: 1, not_attending: 2 }, validate: true

  validates :status, presence: true
  validates :person_id, uniqueness: { scope: :event_id }

  # [[label, value], ...] for the status choices.
  def self.status_options
    statuses.keys.map { |status| [ I18n.t("rsvps.statuses.#{status}"), status ] }
  end

  def status_label
    I18n.t("rsvps.statuses.#{status}") if status
  end
end
