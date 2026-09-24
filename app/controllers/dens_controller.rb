class DensController < ApplicationController
  before_action :authenticate_family!

  DenGroup = Data.define(:den, :youth, :adults)

  def show
    people = Person.includes(:family).order(:last_name, :first_name).to_a
    by_den = people.group_by(&:den)

    @den_groups = Person.regular_dens.map do |den|
      youth = by_den.fetch(den, [])
      family_ids = youth.map(&:family_id)
      adults = by_den.fetch("adult", []).select { |adult| family_ids.include?(adult.family_id) }
      DenGroup.new(den:, youth:, adults:)
    end

    listed_ids = @den_groups.flat_map { |group| group.youth + group.adults }.map(&:id).to_set
    @other_personnel = people.reject { |person| listed_ids.include?(person.id) }
  end
end
