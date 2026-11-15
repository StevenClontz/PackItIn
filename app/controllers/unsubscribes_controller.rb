# Unsubscribing from (and back into) pack email via the signed link in every message. No log in needed:
# the token identifies the person.
class UnsubscribesController < ApplicationController
  skip_forgery_protection only: :create # mail clients POST here directly (List-Unsubscribe-Post)
  before_action :set_person

  def show
  end

  def create
    @person.update!(email_opt_out: true)
    respond_to do |format|
      format.html { redirect_to unsubscribe_path(params[:token]), notice: "#{@person.email} is unsubscribed from pack emails.", status: :see_other }
      format.any { head :ok }
    end
  end

  def destroy
    @person.update!(email_opt_out: false)
    redirect_to unsubscribe_path(params[:token]), notice: "#{@person.email} will get pack emails again.", status: :see_other
  end

  private

  def set_person
    @person = Person.find_by_token_for(:unsubscribe, params[:token])
    render plain: "That unsubscribe link isn't valid.", status: :not_found unless @person
  end
end
