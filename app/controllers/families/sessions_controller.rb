# frozen_string_literal: true

# Adds a second way to sign in: choose a (non-admin) family and enter its street address.
# A street address is a weak secret, so attempts are rate-limited and admins can never sign in this way.
class Families::SessionsController < Devise::SessionsController
  prepend_before_action :require_no_authentication, only: :create_with_address

  rate_limit to: 10, within: 3.minutes, only: :create_with_address,
             with: -> { redirect_to new_family_session_path, alert: "Too many attempts. Please try again in a few minutes." }

  # POST /account/sign_in/address
  def create_with_address
    family = Family.non_admin.find_by(id: address_sign_in_params[:family_id])

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
