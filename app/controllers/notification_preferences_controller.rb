# A family turning pack email on or off for one of its adults (admins can for anyone).
class NotificationPreferencesController < ApplicationController
  before_action :authenticate_family!

  def update
    person = Person.find(params[:id])
    authorize! :update_notifications, person
    person.update!(email_opt_out: params[:email_opt_out] == "1")

    state = person.email_opt_out? ? "off" : "on"
    redirect_to family_path(person.family), notice: "Pack emails turned #{state} for #{person.full_name}.", status: :see_other
  end
end
