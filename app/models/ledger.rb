# The few app-level helpers that reach into the double_entry gem directly.
class Ledger
  # A dollar amount as typed: up to nine digits, optionally with one or two decimals (25, 25.5, 25.50).
  DOLLARS = /\A\d{1,9}(\.\d{1,2})?\z/

  # "Outside the pack": the other side of every deposit and withdrawal.
  def self.external
    DoubleEntry.account(:external)
  end

  # All the money the pack holds. Deposits make :external more negative, so this is its opposite.
  def self.total_held
    -external.balance
  end

  # Typed dollars ("25", "$1,250.50") as Money, or nil when blank or not a dollar amount.
  def self.parse_dollars(input)
    cleaned = input.to_s.strip.delete("$,")
    Money.from_amount(BigDecimal(cleaned)) if cleaned.match?(DOLLARS)
  end

  # A lambda that names the other side of a ledger line ("The Joneses", "General", "Fall Campout",
  # "Outside the pack"). Names are loaded in three queries up front so a statement doesn't query per line.
  def self.counterparty_namer(lines)
    partner_ids = ->(kind) { lines.select { |line| line[:partner_account] == kind }.map { |line| line.partner_scope.to_i }.uniq }
    families = Family.where(id: partner_ids.call("family")).pluck(:id, :name).to_h
    funds = Fund.where(id: partner_ids.call("fund")).pluck(:id, :name).to_h
    events = Event.where(id: partner_ids.call("event")).pluck(:id, :title).to_h

    lambda do |line|
      case line[:partner_account]
      when "family" then families.fetch(line.partner_scope.to_i, "Unknown family")
      when "fund" then funds.fetch(line.partner_scope.to_i, "Unknown fund")
      when "event" then events.fetch(line.partner_scope.to_i, "Unknown event")
      else "Outside the pack"
      end
    end
  end
end
