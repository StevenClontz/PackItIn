# Admins recording a fundraiser's sales for many families at once (FundraiserCredit). The form is
# reviewed first; nothing is recorded until the admin confirms the preview.
class FundraiserCreditsController < ApplicationController
  before_action :authenticate_family!
  before_action { authorize! :create, LedgerTransaction }

  def new
    @fundraiser_credit = FundraiserCredit.new(scout_share_percent: "35", record_proceeds: "1")
    @families = Family.order(:name)
  end

  def create
    @fundraiser_credit = FundraiserCredit.new(fundraiser_params.merge(admin: current_family))
    @families = Family.order(:name)

    if params[:edit].present?
      render :new
    elsif !@fundraiser_credit.valid?
      render :new, status: :unprocessable_content
    elsif params[:confirm].blank?
      render :review
    elsif @fundraiser_credit.save
      redirect_to fund_path(@fundraiser_credit.fund), notice: "#{@fundraiser_credit.name} recorded: #{@fundraiser_credit.total_scout_share.format} credited to #{helpers.pluralize(@fundraiser_credit.lines.size, 'Scout Account')}.", status: :see_other
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  def fundraiser_params
    params.expect(fundraiser_credit: [ :name, :fund_id, :scout_share_percent, :record_proceeds, sales: {} ])
  end
end
