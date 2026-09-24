# frozen_string_literal: true

# Adds a second way to sign in: choose an eligible family and enter its street address.
# A street address is a weak secret, so attempts are rate-limited, and admins and families that
# opted into password-only login can never sign in this way.
class Families::SessionsController < Devise::SessionsController
  # Rails de-duplicates before_actions by method name regardless of :only, so re-declaring
  # require_no_authentication here (rather than adding a second only: :create_with_address one)
  # must list every action needing it, or it silently drops Devise's :new/:create protection.
  prepend_before_action :require_no_authentication, only: %i[new create create_with_address]

  rate_limit to: 10, within: 3.minutes, only: :create_with_address,
             with: -> { redirect_to new_family_session_path, alert: "Too many attempts. Please try again in a few minutes." }

  # POST /account/sign_in/address
  def create_with_address
    family = Family.address_login_eligible.find_by(id: address_sign_in_params[:family_id])

    if family&.street_address_matches?(address_sign_in_params[:street_address])
      set_flash_message!(:notice, :signed_in)
      sign_in(resource_name, family)
      respond_with family, location: after_sign_in_path_for(family)
    else
      self.resource = resource_class.new
      @selected_family_id = address_sign_in_params[:family_id]
      flash.now[:alert] = "Family info not recognized."
      render :new, status: :unprocessable_content
    end
  end

  private

  def address_sign_in_params
    params.fetch(:address_sign_in, {}).permit(:family_id, :street_address)
  end
end
