# Gives a record (a Family or a Fund) its own account in the double-entry ledger.
module HasLedgerAccount
  extend ActiveSupport::Concern

  included do
    # Prepended so it runs before dependent records (a family's people) are destroyed.
    before_destroy :ensure_no_ledger_activity, prepend: true
  end

  def ledger_account
    DoubleEntry.account(self.class.name.underscore.to_sym, scope: self)
  end

  def balance
    persisted? ? ledger_account.balance : Money.new(0)
  end

  # This account's ledger lines, newest first.
  def ledger_lines
    return DoubleEntry::Line.none unless persisted?

    DoubleEntry::Line.where(account: ledger_account.identifier.to_s, scope: ledger_account.scope_identity).order(id: :desc)
  end

  # What the UI calls this record's account; models override it (a Family's is its "Scout Account").
  def ledger_account_label
    "account"
  end

  def ledger_activity?
    ledger_lines.exists?
  end

  private

  # Money history has to stay, so an account that has ever moved money can't be deleted.
  def ensure_no_ledger_activity
    return unless ledger_activity?

    errors.add(:base, "#{name} has #{ledger_account_label} activity and can't be deleted")
    throw :abort
  end
end
