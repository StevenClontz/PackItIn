class Event < ApplicationRecord
  include HasLedgerAccount

  has_many :rsvps, dependent: :destroy
  has_many :rsvp_options, -> { order(:id) }, dependent: :destroy
  # Files uploaded through the description editor, which links to them by blob URL.
  has_many_attached :description_files

  # The signed blob id in an ActiveStorage blob URL, e.g. /rails/active_storage/blobs/redirect/<id>/flyer.pdf
  BLOB_URL_PATTERN = %r{/rails/active_storage/blobs/(?:redirect/|proxy/)?([^/\s)]+)/}

  validates :title, :starts_at, :ends_at, presence: true
  validate :ends_after_start

  before_save :attach_description_files, if: :description_changed?

  scope :upcoming, -> { where(ends_at: Time.current..).order(:starts_at) }
  scope :past, -> { where(ends_at: ...Time.current).order(starts_at: :desc) }

  # After this moment only admins can change RSVPs. Defaults to the end of the event.
  def rsvp_closes_at
    rsvp_deadline_at || ends_at
  end

  def rsvp_open?
    Time.current <= rsvp_closes_at
  end

  # What the UI calls an event's money account, and how messages name the event.
  def ledger_account_label
    "Event Account"
  end

  def ledger_account_name
    title
  end

  private

  # Keep files linked from the description owned by this event, so they aren't left as unattached blobs
  # and are purged with it. Files whose links are later removed stay attached.
  def attach_description_files
    attached_ids = description_files.blobs.ids
    blobs = description.to_s.scan(BLOB_URL_PATTERN).flatten.uniq.filter_map { |id| ActiveStorage::Blob.find_signed(id) }
    new_blobs = blobs.reject { |blob| attached_ids.include?(blob.id) }
    description_files.attach(new_blobs) if new_blobs.any?
  end

  def ends_after_start
    return if starts_at.blank? || ends_at.blank?

    errors.add(:ends_at, "must be after the start time") unless ends_at > starts_at
  end
end
