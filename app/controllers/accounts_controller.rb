# The statement for a family's Scout Account or an event's Event Account. Fund statements are on the fund page.
class AccountsController < ApplicationController
  STATEMENT_LINES = 200

  before_action :authenticate_family!

  def show
    @owner = params[:event_id] ? Event.find(params[:event_id]) : Family.find(params[:family_id])
    # A Scout Account is private to its family and admins; an Event Account is readable by every family.
    authorize! (@owner.is_a?(Family) ? :view_account : :read), @owner
    @lines = @owner.ledger_lines.limit(STATEMENT_LINES)
  end
end
