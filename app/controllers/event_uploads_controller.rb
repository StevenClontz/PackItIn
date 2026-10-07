# The stock /rails/active_storage/direct_uploads endpoint accepts uploads from anyone; the event
# description editor uploads here instead, which only admins (who can create events) may use.
class EventUploadsController < ActiveStorage::DirectUploadsController
  before_action :authenticate_family!
  before_action { authorize! :create, Event }

  rescue_from CanCan::AccessDenied do
    head :forbidden
  end

  private

  # Like ApplicationController (which this doesn't inherit from): our Devise resource is Family.
  def current_ability
    @current_ability ||= Ability.new(current_family)
  end
end
