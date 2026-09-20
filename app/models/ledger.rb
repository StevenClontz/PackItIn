# The few app-level helpers that reach into the double_entry gem directly.
class Ledger
  # "Outside the pack": the other side of every deposit and withdrawal.
  def self.external
    DoubleEntry.account(:external)
  end

  # All the money the pack holds. Deposits make :external more negative, so this is its opposite.
  def self.total_held
    -external.balance
  end

  # A lambda that names the other side of a ledger line ("The Joneses", "General", "Outside the pack").
  # Names are loaded in two queries up front so a statement doesn't query per line.
  def self.counterparty_namer(lines)
    partner_ids = ->(kind) { lines.select { |line| line[:partner_account] == kind }.map { |line| line.partner_scope.to_i }.uniq }
    families = Family.where(id: partner_ids.call("family")).pluck(:id, :name).to_h
    funds = Fund.where(id: partner_ids.call("fund")).pluck(:id, :name).to_h

    lambda do |line|
      case line[:partner_account]
      when "family" then families.fetch(line.partner_scope.to_i, "Unknown family")
      when "fund" then funds.fetch(line.partner_scope.to_i, "Unknown fund")
      else "Outside the pack"
      end
    end
  end
end
