class DensController < ApplicationController
  before_action :authenticate_family!

  DenGroup = Data.define(:den, :leaders, :youth, :adults)

  def show
    people = Person.includes(:family).order(:last_name, :first_name).to_a
    by_den = people.group_by(&:den)

    leaderships = Leadership.includes(person: :family).in_role_order.to_a
    @pack_leaders, den_leaders = leaderships.partition { |leadership| !leadership.den_role? }
    den_leaders_by_den = den_leaders.group_by(&:den)

    @den_groups = Person.regular_dens.map do |den|
      youth = by_den.fetch(den, [])
      family_ids = youth.map(&:family_id)
      adults = by_den.fetch("adult", []).select { |adult| family_ids.include?(adult.family_id) }
      DenGroup.new(den:, leaders: den_leaders_by_den.fetch(den, []), youth:, adults:)
    end

    listed_ids = @den_groups.flat_map { |group| group.youth + group.adults }.map(&:id).to_set
    listed_ids.merge(leaderships.map(&:person_id))
    @other_personnel = people.reject { |person| listed_ids.include?(person.id) }
  end
end
