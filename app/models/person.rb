class Person < ApplicationRecord
  belongs_to :family

  enum :position, { adult: 0, lion: 1, tiger: 2, wolf: 3, bear: 4, webelos: 5, aol: 6, youth: 7 }, validate: true

  validates :first_name, :last_name, :position, presence: true

  # [[label, value], ...] for the position <select>.
  def self.position_options
    positions.keys.map { |position| [ I18n.t("people.positions.#{position}"), position ] }
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def position_label
    I18n.t("people.positions.#{position}")
  end
end
