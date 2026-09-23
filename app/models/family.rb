class Family < ApplicationRecord
  # No :validatable (requires an email column) and no email-based modules
  # (:recoverable, :confirmable); validations are declared below.
  devise :database_authenticatable, :rememberable

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
  scope :address_login_eligible, -> { where(admin: false, password_only: false) }

  # Addresses are compared as bare sequences of letters and digits, ignoring case, spacing and punctuation.
  def self.normalize_address(value)
    value.to_s.downcase.gsub(/[^[:alnum:]]/, "")
  end

  def street_address_matches?(input)
    expected = self.class.normalize_address(street_address)
    expected.present? && ActiveSupport::SecurityUtils.secure_compare(expected, self.class.normalize_address(input))
  end

  # Devise calls this to look up the resource being signed in. It's overridden (rather than just
  # listing :email/:phone_number in config.authentication_keys) because those fields live on
  # Person, not Family: a match resolves to that person's family. Still requires the real
  # password, so unlike address login this isn't restricted to address_login_eligible families.
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

  private

  def password_required?
    !persisted? || !password.nil? || !password_confirmation.nil?
  end
end
