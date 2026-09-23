class Person < ApplicationRecord
  belongs_to :family
  has_many :rsvps, dependent: :destroy

  enum :position, { adult: 0, lion: 1, tiger: 2, wolf: 3, bear: 4, webelos: 5, aol: 6, youth: 7 }, validate: true

  before_validation :normalize_contact_info

  validates :first_name, :last_name, :position, presence: true
  validates :email, uniqueness: { case_sensitive: false },
                     format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }, allow_blank: true
  validates :phone_number, uniqueness: true,
                            format: { with: /\A\d{10}\z/, message: "must be a 10-digit phone number" }, allow_blank: true

  # [[label, value], ...] for the position <select>.
  def self.position_options
    positions.keys.map { |position| [ I18n.t("people.positions.#{position}"), position ] }
  end

  def self.normalize_phone_number(value)
    value.to_s.gsub(/\D/, "")
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def position_label
    I18n.t("people.positions.#{position}")
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
