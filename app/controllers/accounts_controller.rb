# A family's Scout Account statement. Fund statements are on the fund page.
class AccountsController < ApplicationController
  STATEMENT_LINES = 200

  before_action :authenticate_family!

  def show
    @family = Family.find(params[:family_id])
    authorize! :view_account, @family
    @lines = @family.ledger_lines.limit(STATEMENT_LINES)
  end
end
