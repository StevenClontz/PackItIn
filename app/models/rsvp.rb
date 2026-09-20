class Rsvp < ApplicationRecord
  belongs_to :event
  belongs_to :person
  belongs_to :rsvp_option, optional: true

  enum :status, { attending: 0, maybe: 1, not_attending: 2 }, validate: true

  before_validation { self.rsvp_option = nil if not_attending? }

  validates :status, presence: true
  validates :person_id, uniqueness: { scope: :event_id }
  validate :option_belongs_to_event
  validate :option_chosen_when_event_has_options

  # [[label, value], ...] for the status choices.
  def self.status_options
    statuses.keys.map { |status| [ I18n.t("rsvps.statuses.#{status}"), status ] }
  end

  def status_label
    I18n.t("rsvps.statuses.#{status}") if status
  end

  # "Attending - Full weekend"; on an event with options, "Attending - choose an option" if none is set yet.
  def summary
    return status_label if not_attending? || event.blank?

    if rsvp_option
      "#{status_label} - #{rsvp_option.name}"
    elsif event.rsvp_options.any?
      "#{status_label} - choose an option"
    else
      status_label
    end
  end

  private

  def option_belongs_to_event
    return if rsvp_option.blank? || rsvp_option.event_id == event_id

    errors.add(:rsvp_option, "isn't an option for this event")
  end

  # Only checked when saving, so an answer given before the event gained options stays until it is changed.
  def option_chosen_when_event_has_options
    return if rsvp_option.present? || not_attending? || status.blank? || event.blank?

    errors.add(:rsvp_option, "must be chosen") if event.rsvp_options.exists?
  end
end
