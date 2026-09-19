# frozen_string_literal: true

# Devise's :registerable exposes DELETE /families, which would let the signed-in
# family (admin or not) delete its own account. That is never allowed, so this
# denies unconditionally rather than consulting Ability.
class Families::RegistrationsController < Devise::RegistrationsController
  def destroy
    raise CanCan::AccessDenied
  end
end
