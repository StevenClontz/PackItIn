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
      can :read, Family
      can :manage, Family, id: family.id

      # Families can never be deleted by themselves.
      cannot :destroy, Family
    end
  end
end
