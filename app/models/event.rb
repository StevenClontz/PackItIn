class Event < ApplicationRecord
  has_many :rsvps, dependent: :destroy

  validates :title, :starts_at, :ends_at, presence: true
  validate :ends_after_start

  scope :upcoming, -> { where(ends_at: Time.current..).order(:starts_at) }
  scope :past, -> { where(ends_at: ...Time.current).order(starts_at: :desc) }

  # After this moment only admins can change RSVPs. Defaults to the end of the event.
  def rsvp_closes_at
    rsvp_deadline_at || ends_at
  end

  def rsvp_open?
    Time.current <= rsvp_closes_at
  end

  private

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") unless ends_at > starts_at
  end
end
