# frozen_string_literal: true

# Devise's :registerable exposes DELETE /families (account cancellation). Families
# may not delete themselves, so it goes through CanCan, which denies :destroy.
class Families::RegistrationsController < Devise::RegistrationsController
  def destroy
    authorize! :destroy, resource
  end
end
