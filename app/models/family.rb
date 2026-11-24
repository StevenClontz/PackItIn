class Family < ApplicationRecord
  # No :validatable (requires an email column) and no email-based modules
  # (:recoverable, :confirmable); validations are declared below.
  devise :database_authenticatable, :rememberable, :recoverable

  include HasLedgerAccount

  has_many :people, dependent: :destroy

  # Not a DB column: the sign-in form's identifier field, which accepts a username or a person's
  # email/phone number (see .find_for_database_authentication and config.authentication_keys).
  attr_accessor :login

  # Prefixed because bare postal codes collide with ActiveRecord methods (`or`, `id`).
  enum :state, {
    al: 0, ak: 1, az: 2, ar: 3, ca: 4, co: 5, ct: 6, de: 7, dc: 8, fl: 9, ga: 10, hi: 11, id: 12,
    il: 13, in: 14, ia: 15, ks: 16, ky: 17, la: 18, me: 19, md: 20, ma: 21, mi: 22, mn: 23, ms: 24,
    mo: 25, mt: 26, ne: 27, nv: 28, nh: 29, nj: 30, nm: 31, ny: 32, nc: 33, nd: 34, oh: 35, ok: 36,
    or: 37, pa: 38, ri: 39, sc: 40, sd: 41, tn: 42, tx: 43, ut: 44, vt: 45, va: 46, wa: 47, wv: 48,
    wi: 49, wy: 50
  }, prefix: true, validate: true

  validates :username, presence: true,
                       uniqueness: { case_sensitive: false },
                       length: { in: 3..30 },
                       format: { with: /\A[a-z0-9_.-]+\z/i, message: "may only contain letters, numbers, underscores, periods and hyphens" }
  validates :name, :street_address, :city, :state, :zip, presence: true
  validates :zip, format: { with: /\A\d{5}(-\d{4})?\z/, message: "must be a 5-digit ZIP or ZIP+4" }, allow_blank: true
  validates :password, presence: true, confirmation: true, length: { in: Devise.password_length }, if: :password_required?

  scope :non_admin, -> { where(admin: false) }

  # Emailed sign-in: choose the family on the sign-in page, and its adults get a 6-digit code and
  # a link (Families::EmailLoginsController). Either one signs the family in once.
  LOGIN_CODE_TTL = 15.minutes
  MAX_LOGIN_CODE_ATTEMPTS = 5
  LOGIN_CODE_RESEND_WAIT = 1.minute

  # Families with somewhere to send the code: an adult with an email address (see #email_addresses).
  scope :email_login_eligible, -> { where(id: Person.adult.where.not(email: nil).select(:family_id)) }

  # Tied to login_code_sent_at, so the link dies once it's used, a newer code is sent, or it expires.
  generates_token_for :email_login, expires_in: LOGIN_CODE_TTL do
    login_code_sent_at
  end

  # Devise calls this to look up the resource being signed in. It's overridden (rather than just
  # listing :email/:phone_number in config.authentication_keys) because those fields live on
  # Person, not Family: a match resolves to that person's family.
  def self.find_for_database_authentication(warden_conditions)
    login = warden_conditions[:login].to_s.strip
    return nil if login.blank?

    find_by("lower(username) = ?", login.downcase) ||
      Person.find_by("lower(email) = ?", login.downcase)&.family ||
      Person.find_by(phone_number: Person.normalize_phone_number(login))&.family
  end

  # [[label, value], ...] for the state <select>.
  def self.state_options
    states.keys.map { |state| [ I18n.t("families.states.#{state}"), state ] }
  end

  def state_label
    I18n.t("families.states.#{state}") if state
  end

  # A family's money account is called its Scout Account in the UI.
  def ledger_account_label
    "Scout Account"
  end

  # Where the family's mail goes: its adults' email addresses. Youth emails never get account mail.
  def email_addresses
    people.select { |person| person.adult? && person.email.present? }.map(&:email)
  end

  # The adults who get pack announcements and reminders (see Person.notifiable).
  def notifiable_people
    people.notifiable
  end

  # Devise mail (password resets) goes out through the job queue rather than during the request.
  def send_devise_notification(notification, *args)
    devise_mailer.send(notification, self, *args).deliver_later
  end

  # Starts a fresh emailed sign-in, replacing any earlier code and link, and returns the new code.
  # Only a digest is stored.
  def start_email_login!
    code = format("%06d", SecureRandom.random_number(1_000_000))
    # floor(6): the DB keeps microseconds, and the link token must match the reloaded value.
    update_columns(login_code_digest: login_code_digest_for(code), login_code_sent_at: Time.current.floor(6), login_code_attempts: 0)
    code
  end

  def login_code_pending?
    login_code_digest.present? && login_code_sent_at&.after?(LOGIN_CODE_TTL.ago) && login_code_attempts < MAX_LOGIN_CODE_ATTEMPTS
  end

  def recently_sent_login_code?
    login_code_sent_at.present? && login_code_sent_at.after?(LOGIN_CODE_RESEND_WAIT.ago)
  end

  # True (and the code is used up) on a match. A miss counts toward MAX_LOGIN_CODE_ATTEMPTS.
  def verify_login_code(code)
    return false unless login_code_pending?

    if ActiveSupport::SecurityUtils.secure_compare(login_code_digest, login_code_digest_for(code.to_s.gsub(/\D/, "")))
      finish_email_login!
      true
    else
      increment!(:login_code_attempts, touch: false)
      false
    end
  end

  # Uses up the pending code and link.
  def finish_email_login!
    update_columns(login_code_digest: nil, login_code_sent_at: nil, login_code_attempts: 0)
  end

  private

  # Keyed per family, so the same code for two families never has the same digest.
  def login_code_digest_for(code)
    key = Rails.application.key_generator.generate_key("email login code")
    OpenSSL::HMAC.hexdigest("SHA256", key, "#{id}:#{code}")
  end

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
end
