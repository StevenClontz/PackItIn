class FundsController < ApplicationController
  before_action :authenticate_family!
  load_and_authorize_resource

  def index
    @funds = @funds.order(:name)
    @total_held = Ledger.total_held
    # Scout Accounts and Event Accounts are admin-only, pending a future transparency dashboard.
    @families = Family.accessible_by(current_ability, :view_account).order(:name)
    @events = Event.accessible_by(current_ability, :view_account).order(starts_at: :desc)
  end

  def show
    @lines = @fund.ledger_lines.limit(AccountsController::STATEMENT_LINES)
  end

  def new
  end

  def create
    if @fund.save
      redirect_to @fund, notice: "Fund created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @fund.update(fund_params)
      redirect_to @fund, notice: "Fund updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @fund.destroy
      redirect_to funds_path, notice: "Fund deleted.", status: :see_other
    else
      redirect_to @fund, alert: @fund.errors.full_messages.to_sentence, status: :see_other
    end
  end

  private

  def fund_params
    params.expect(fund: %i[name description])
  end
end
