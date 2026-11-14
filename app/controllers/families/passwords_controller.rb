# frozen_string_literal: true

# "Forgot your password?": look the family up the same ways it can log in (username, or an adult's
# email or phone), then email a reset link to the family's adults. The response never says whether
# the account exists or has an email address, so the form can't be used to probe for accounts.
class Families::PasswordsController < Devise::PasswordsController
  rate_limit to: 5, within: 15.minutes, only: :create,
             with: -> { redirect_to new_family_password_path, alert: "Too many reset requests. Please try again later." }

  # POST /account/password
  def create
    family = Family.find_for_database_authentication(login: params.dig(:family, :login))
    family.send_reset_password_instructions if family&.email_addresses&.any?

    redirect_to new_family_session_path, notice: "If that account has an adult with an email address, we've sent them a link to reset the password."
  end
end
