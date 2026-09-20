# One way to attend an event ("Day trip only", "Full weekend"), defined per event by an admin.
#
# It can cost money per person: `cost` for everyone, or, when `youth_cost` is also set, `cost` for adults
# and `youth_cost` for anyone who isn't an adult (lion, tiger, wolf, bear, webelos, AOL, youth). A youth
# cost of $0 makes it free for youth; leaving it blank means youth pay the same as everyone.
class RsvpOption < ApplicationRecord
  include CentsAttribute

  belongs_to :event
  # Responses keep their answer when an option is deleted; they just lose the choice and need a new one.
  has_many :rsvps, dependent: :nullify

  cents_attribute :cost
  cents_attribute :youth_cost

  validates :name, presence: true, uniqueness: { scope: :event_id, case_sensitive: false }

  # Whether anyone is charged for this option.
  def costed?
    cost_cents.to_i.positive? || youth_cost_cents.to_i.positive?
  end

  # What this person pays for the option (zero when nothing is charged).
  def cost_for(person)
    cents = person.adult? ? cost_cents : (youth_cost_cents || cost_cents)
    Money.new(cents.to_i)
  end

  # "Full weekend ($30.00)" using this person's price, or just the name if it costs them nothing.
  def label_for(person)
    price = cost_for(person)
    price.positive? ? "#{name} (#{price.format})" : name
  end

  # For the options list: "$60.00 per person", "$60.00 per adult, $30.00 per youth", "free for adults, ...".
  def cost_summary
    return unless costed?

    adult = cost_cents.to_i
    return "#{Money.new(adult).format} per person" if youth_cost_cents.nil? || youth_cost_cents == adult

    adult_part = adult.zero? ? "free for adults" : "#{Money.new(adult).format} per adult"
    youth_part = youth_cost_cents.zero? ? "free for youth" : "#{Money.new(youth_cost_cents).format} per youth"
    "#{adult_part}, #{youth_part}"
  end
end
