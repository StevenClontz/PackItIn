module PeopleHelper
  # The little pill showing a person's den (Adult, Lion, ... AOL, Other Youth), shown next to their name.
  def den_badge(person)
    tag.span(person.den_label, class: "rounded-full bg-gray-100 px-2 py-0.5 text-xs font-medium text-gray-700")
  end
end
