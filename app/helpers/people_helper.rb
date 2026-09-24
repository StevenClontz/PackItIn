module PeopleHelper
  # The little pill showing a person's den (Adult, Lion, ... AOL, Other Youth), shown next to
  # their name. An adult also gets their family's regular dens appended, e.g. "(Lion)" or
  # "(Tiger/Wolf)" (see Person#family_dens).
  def den_badge(person)
    tag.span(den_badge_text(person), class: "rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700")
  end

  private

  def den_badge_text(person)
    return person.den_label if person.family_dens.empty?
    "#{person.den_label} (#{person.family_dens.map { |den| I18n.t("people.dens.#{den}") }.join('/')})"
  end
end
