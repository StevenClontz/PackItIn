module PeopleHelper
  # The little pill showing a person's position (Adult, Lion, ... AOL, Youth), shown next to their name.
  def position_badge(person)
    tag.span(person.position_label, class: "rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700")
  end
end
