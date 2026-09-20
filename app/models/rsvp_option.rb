# One way to attend an event ("Day trip only", "Full weekend"), defined per event by an admin.
class RsvpOption < ApplicationRecord
  belongs_to :event
  # Responses keep their answer when an option is deleted; they just lose the choice and need a new one.
  has_many :rsvps, dependent: :nullify

  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }
end
