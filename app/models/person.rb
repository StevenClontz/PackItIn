class Person < ApplicationRecord
  belongs_to :family
  has_many :rsvps, dependent: :destroy

  enum :den, { adult: 0, lion: 1, tiger: 2, wolf: 3, bear: 4, webelos: 5, aol: 6, other_youth: 7 }, validate: true

  before_validation :normalize_contact_info

  validates :first_name, :last_name, :den, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validates :phone_number, uniqueness: true,
                            format: { with: /\A\d{10}\z/, message: "must be a 10-digit phone number" }, allow_blank: true

  # [[label, value], ...] for the den <select>.
  def self.den_options
    dens.keys.map { |den| [ I18n.t("people.dens.#{den}"), den ] }
  end

  # The actual Cub Scout dens, excluding the "adult" and "other_youth" catch-alls.
  def self.regular_dens
    dens.keys - %w[adult other_youth]
  end

  def self.normalize_phone_number(value)
    value.to_s.gsub(/\D/, "")
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def den_label
    I18n.t("people.dens.#{den}")
  end

  def formatted_phone_number
    return nil if phone_number.blank?
    "(#{phone_number[0..2]}) #{phone_number[3..5]}-#{phone_number[6..9]}"
  end

  private

  # Blank strings would collide on the unique index; punctuation in a phone number would not
  # match the normalized digits-only value used for login lookups (see Family#login).
  def normalize_contact_info
    self.email = email.presence
    self.phone_number = phone_number.present? ? self.class.normalize_phone_number(phone_number) : nil
  end
end
