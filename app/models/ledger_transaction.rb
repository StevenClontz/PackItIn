# One credit, debit or transfer, as entered by an admin. Accounts are chosen as "outside", "family:<id>" or
# "fund:<id>": from outside is a deposit (credit), to outside is a withdrawal (debit), anything else a transfer.
class LedgerTransaction
  include ActiveModel::Model

  OUTSIDE = "outside".freeze
  AMOUNT_FORMAT = /\A\d{1,9}(\.\d{1,2})?\z/

  attr_accessor :from, :to, :amount, :memo, :admin

  validates :memo, length: { maximum: 200 }
  validate :accounts_are_valid, :accounts_differ, :amount_is_valid

  # [[label, value], ...] for the From and To selects.
  def self.account_options
    [ [ "Outside the pack (money in or out)", OUTSIDE ] ] +
      Family.order(:name).map { |family| [ "Family: #{family.name}", "family:#{family.id}" ] } +
      Fund.order(:name).map { |fund| [ "Fund: #{fund.name}", "fund:#{fund.id}" ] }
  end

  # The gem's error messages are for developers; every expected failure is validated for up front.
  def save
    return false unless valid?

    DoubleEntry.transfer(money, from: account_for(from_record), to: account_for(to_record), code: code,
                                metadata: { memo: memo.presence, admin_id: admin&.id }.compact)
    true
  rescue DoubleEntry::DoubleEntryError => error
    errors.add(:base, "The transaction couldn't be recorded (#{error.class.name.demodulize})")
    false
  end

  def code
    if from_record == :outside then :deposit
    elsif to_record == :outside then :withdrawal
    else :transfer
    end
  end

  def money
    Money.from_amount(BigDecimal(cleaned_amount))
  end

  # The family or fund whose statement is most relevant afterwards: where the money went, or came from.
  def subject
    to_record == :outside ? from_record : to_record
  end

  private

  def cleaned_amount
    amount.to_s.strip.delete("$,")
  end

  def from_record
    resolve(from)
  end

  def to_record
    resolve(to)
  end

  def resolve(reference)
    case reference.to_s
    when OUTSIDE then :outside
    when /\Afamily:(\d+)\z/ then Family.find_by(id: $1)
    when /\Afund:(\d+)\z/ then Fund.find_by(id: $1)
    end
  end

  def account_for(record)
    record == :outside ? Ledger.external : record.ledger_account
  end

  def accounts_are_valid
    errors.add(:from, "must be an account") if from_record.nil?
    errors.add(:to, "must be an account") if to_record.nil?
  end

  def accounts_differ
    return if from_record.nil? || to_record.nil?

    if from_record == :outside && to_record == :outside
      errors.add(:base, "Choose at least one account inside the pack")
    elsif from_record == to_record
      errors.add(:to, "must be different from the From account")
    end
  end

  def amount_is_valid
    if cleaned_amount.blank?
      errors.add(:amount, "can't be blank")
    elsif !cleaned_amount.match?(AMOUNT_FORMAT)
      errors.add(:amount, "must be a dollar amount such as 25 or 25.50")
    elsif BigDecimal(cleaned_amount).zero?
      errors.add(:amount, "must be greater than zero")
    end
  end
end
