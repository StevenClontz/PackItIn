module DensHelper
  def person_name_or_link(person)
    return person.full_name unless can? :show, person
    link_to person.full_name, person_path(person), class: "font-medium text-blue-600 hover:underline"
  end

  def family_name_or_link(family)
    return family.name unless can? :show, family
    link_to family.name, family_path(family), class: "text-blue-600 hover:underline"
  end
end
