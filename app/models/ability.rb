# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(family)
    # Guests (no signed-in family) have no abilities.
    return unless family.present?

    if family.admin?
      can :manage, :all
      cannot :destroy, Family, id: family.id
    else
      # Not :manage: with an `id` condition CanCan would build `Family.new(id: family.id)`
      # for :new, which would then pass the check.
      can :read, Family
      can :update, Family, id: family.id

      # People are only visible to their own family, and only admins can change them.
      can :read, Person, family_id: family.id
    end
  end
end
