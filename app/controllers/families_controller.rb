class FamiliesController < ApplicationController
  before_action :authenticate_family!
  load_and_authorize_resource

  def index
    @families = @families.order(:username)
  end

  def show
    @people = @family.people.order(:last_name, :first_name)
  end

  def new
  end

  def create
    if @family.save
      redirect_to @family, notice: "Family created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    editing_self = @family == current_family
    attrs = update_params

    if @family.update(attrs)
      bypass_sign_in(@family) if editing_self # a new password would otherwise sign us out
      redirect_to @family, notice: "Family updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @family.destroy
      redirect_to families_path, notice: "Family deleted.", status: :see_other
    else
      redirect_to @family, alert: @family.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  # Only admins may set `admin`, and never on themselves, so the last admin can't be demoted.
  def family_params
    permitted = %i[username password password_confirmation name street_address city state zip password_only]
    permitted << :admin if current_family.admin? && @family != current_family
    params.expect(family: permitted)
  end

  # A blank password field means "keep the current password".
  def update_params
    family_params.tap do |attrs|
      attrs.delete(:password) if attrs[:password].blank?
      attrs.delete(:password_confirmation) if attrs[:password_confirmation].blank?
    end
  end
end
