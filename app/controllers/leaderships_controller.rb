# Admins add and remove an adult's leadership roles from the person page.
class LeadershipsController < ApplicationController
  before_action :authenticate_family!

  def create
    @person = Person.find(params[:person_id])
    @family = @person.family
    @leadership = @person.leaderships.build(leadership_params)
    authorize! :create, @leadership

    if @leadership.save
      redirect_to person_path(@person), notice: "#{@person.full_name} is now #{@leadership.label}."
    else
      render "people/show", status: :unprocessable_content
    end
  end

  def destroy
    leadership = Leadership.find(params[:id])
    authorize! :destroy, leadership
    leadership.destroy!
    redirect_to person_path(leadership.person), notice: "Removed #{leadership.label} from #{leadership.person.full_name}.", status: :see_other
  end

  private

  def leadership_params
    params.expect(leadership: %i[role den])
  end
end
