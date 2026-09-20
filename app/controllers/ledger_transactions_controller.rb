class LedgerTransactionsController < ApplicationController
  before_action :authenticate_family!
  before_action { authorize! :create, LedgerTransaction }

  def new
    @ledger_transaction = LedgerTransaction.new
  end

  def create
    @ledger_transaction = LedgerTransaction.new(ledger_transaction_params.merge(admin: current_family))

    if @ledger_transaction.save
      redirect_to statement_path_for(@ledger_transaction.subject), notice: "Transaction recorded."
    else
      render :new, status: :unprocessable_content
    end
  end

  private

  # `admin` is always the signed-in family, never a parameter.
  def ledger_transaction_params
    params.expect(ledger_transaction: %i[from to amount memo])
  end

  def statement_path_for(account_owner)
    case account_owner
    when Family then family_account_path(account_owner)
    when Event then event_path(account_owner)
    else fund_path(account_owner)
    end
  end
end
