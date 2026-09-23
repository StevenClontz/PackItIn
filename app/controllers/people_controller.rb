class PeopleController < ApplicationController
  before_action :authenticate_family!
  before_action :set_family, only: %i[index new create]
  before_action :set_person, only: %i[show edit update destroy]

  # Loaded by hand rather than with `load_and_authorize_resource through: :family`: that would
  # silently filter another family's index to an empty page instead of denying access.

  def index
    authorize! :read, Person.new(family: @family)
    @people = @family.people.order(:last_name, :first_name)
  end

  def show
    authorize! :read, @person
  end

  def new
    @person = @family.people.build
    authorize! :create, @person
  end

  def create
    @person = @family.people.build(person_params)
    authorize! :create, @person

    if @person.save
      redirect_to family_people_path(@family), notice: "#{@person.full_name} was added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
    authorize! :update, @person
  end

  def update
    authorize! :update, @person

    if @person.update(person_params)
      redirect_to family_people_path(@family), notice: "#{@person.full_name} was updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize! :destroy, @person
    @person.destroy!
    redirect_to family_people_path(@family), notice: "#{@person.full_name} was deleted.", status: :see_other
  end

  private

  def set_family
    @family = Family.find(params[:family_id])
  end

  def set_person
    @person = Person.find(params[:id])
    @family = @person.family
  end

  # The family is fixed by the URL and can't be reassigned.
  def person_params
    params.expect(person: %i[first_name last_name den email phone_number])
  end
end
