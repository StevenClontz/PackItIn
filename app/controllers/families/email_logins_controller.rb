# frozen_string_literal: true

# Log in by email: choose your family, and its adults get a 6-digit code and a one-time link
# (Family#start_email_login!). Either one signs the family in.
class Families::EmailLoginsController < ApplicationController
  SESSION_KEY = :email_login_family_id

  before_action :redirect_signed_in_family

  # Each limit needs its own name: unnamed limits in one controller share a single counter.
  rate_limit to: 5, within: 15.minutes, only: :create, name: "request-code",
             with: -> { redirect_to new_family_session_path, alert: "Too many sign-in emails requested. Please try again later." }
  rate_limit to: 10, within: 3.minutes, only: %i[verify_code use_link], name: "enter-code",
             with: -> { redirect_to new_family_session_path, alert: "Too many attempts. Please try again in a few minutes." }

  # POST /account/sign_in/email
  def create
    family = Family.email_login_eligible.find_by(id: params[:family_id])
    unless family
      redirect_to new_family_session_path, alert: "Choose your family."
      return
    end

    unless family.recently_sent_login_code?
      code = family.start_email_login!
      LoginMailer.sign_in(family, code, family.generate_token_for(:email_login)).deliver_later
    end

    session[SESSION_KEY] = family.id
    redirect_to email_login_code_path
  end

  # GET /account/sign_in/code
  def code
    @family = session_family
    redirect_to new_family_session_path unless @family
  end

  # POST /account/sign_in/code
  def verify_code
    @family = session_family
    return redirect_to(new_family_session_path) unless @family

    if @family.verify_login_code(params[:code])
      session.delete(SESSION_KEY)
      sign_in_family(@family)
    else
      flash.now[:alert] = "That code is wrong or has expired."
      render :code, status: :unprocessable_content
    end
  end

  # GET /account/sign_in/email/:token
  # Only shows a button: mail scanners prefetch links, and must not use up the one-time link.
  def link
    @family = Family.find_by_token_for(:email_login, params[:token])
    redirect_to new_family_session_path, alert: "That sign-in link has expired or was already used." unless @family
  end

  # POST /account/sign_in/email/:token
  def use_link
    family = Family.find_by_token_for(:email_login, params[:token])
    return redirect_to(new_family_session_path, alert: "That sign-in link has expired or was already used.") unless family

    family.finish_email_login!
    session.delete(SESSION_KEY)
    sign_in_family(family)
  end

  private

  def session_family
    Family.email_login_eligible.find_by(id: session[SESSION_KEY]) if session[SESSION_KEY]
  end

  def sign_in_family(family)
    sign_in(:family, family)
    redirect_to after_sign_in_path_for(family), notice: I18n.t("devise.sessions.signed_in")
  end

  def redirect_signed_in_family
    redirect_to root_path, notice: I18n.t("devise.failure.already_authenticated") if family_signed_in?
  end
end
