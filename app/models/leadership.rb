# A pack leadership role held by an adult. Den Leader and Assistant Den Leader belong to a
# den; every other role is pack-wide. Display only: roles don't grant any app permissions.
class Leadership < ApplicationRecord
  belongs_to :person

  # Den roles start at 20 so more pack-wide roles can be added without renumbering.
  enum :role, {
    cubmaster: 0, assistant_cubmaster: 1, committee_chair: 2, committee_member: 3,
    treasurer: 4, secretary: 5, chartered_org_rep: 6, pack_trainer: 7,
    den_leader: 20, assistant_den_leader: 21
  }, validate: true

  # Same integers as Person's den enum, limited to the real Cub Scout dens.
  enum :den, Person.dens.slice(*Person.regular_dens), prefix: true, validate: { allow_nil: true }

  DEN_ROLES = %w[den_leader assistant_den_leader].freeze

  scope :in_role_order, -> { order(:role, :den) }
  scope :den_roles, -> { where(role: DEN_ROLES) }
  scope :pack_roles, -> { where.not(role: DEN_ROLES) }

  validates :role, uniqueness: { scope: %i[person_id den], message: "is already held by this person" }
  validates :den, presence: { message: "must be chosen for this role" }, if: :den_role?
  validates :den, absence: { message: "is only for Den Leader and Assistant Den Leader" }, unless: :den_role?
  validate :person_is_adult

  # [[label, value], ...] for the role <select>.
  def self.role_options
    roles.keys.map { |role| [ role_label(role), role ] }
  end

  # [[label, value], ...] for the den <select>.
  def self.den_options
    dens.keys.map { |den| [ I18n.t("people.dens.#{den}"), den ] }
  end

  def self.role_label(role)
    I18n.t("people.leadership_roles.#{role}")
  end

  def den_role?
    DEN_ROLES.include?(role)
  end

  # "Cubmaster", or "Den Leader (Lion)".
  def label
    text = self.class.role_label(role)
    den_role? && den ? "#{text} (#{I18n.t("people.dens.#{den}")})" : text
  end

  private

  def person_is_adult
    errors.add(:person, "must be an adult to hold a leadership role") if person && !person.adult?
  end
end
