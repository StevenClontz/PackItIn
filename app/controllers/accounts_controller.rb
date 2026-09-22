# The statement for a family's Scout Account or an event's Event Account. Fund statements are on the fund page.
class AccountsController < ApplicationController
  STATEMENT_LINES = 200

  before_action :authenticate_family!

  def show
    @owner = params[:event_id] ? Event.find(params[:event_id]) : Family.find(params[:family_id])
    # A Scout Account is private to its family and admins; an Event Account is admin-only too,
    # pending a future pack-wide transparency dashboard.
    authorize! :view_account, @owner
    @lines = @owner.ledger_lines.limit(STATEMENT_LINES)
  end
end
