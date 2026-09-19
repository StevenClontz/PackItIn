class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :configure_permitted_parameters, if: :devise_controller?

  # CanCanCan defaults to `current_user`; our Devise resource is Family.
  def current_ability
    @current_ability ||= Ability.new(current_family)
  end

  rescue_from CanCan::AccessDenied do |_exception|
    redirect_to(family_signed_in? ? root_path : new_family_session_path, alert: "You are not authorized to access that page.")
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: [ :username ])
    devise_parameter_sanitizer.permit(:account_update, keys: [ :username ])
  end
end
