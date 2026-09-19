# frozen_string_literal: true

class Ability
  include CanCan::Ability

  def initialize(family)
    # Guests (no signed-in family) have no abilities.
    return unless family.present?

    can :read, Family
    can :manage, Family, id: family.id

    # Families can never be deleted, not even by themselves.
    cannot :destroy, Family
  end
end
