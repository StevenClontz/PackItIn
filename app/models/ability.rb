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

      # Events are read-only for families, who RSVP their own people until the event's RSVP deadline
      # passes (a block: the deadline falls back to ends_at, which a hash condition can't express).
      can :read, Event
      can :read, Rsvp, person: { family_id: family.id }
      can %i[create update], Rsvp do |rsvp|
        rsvp.person&.family_id == family.id && rsvp.event&.rsvp_open?
      end
    end
  end
end
