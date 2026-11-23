# Recording a fundraiser (popcorn, wreaths...) in one go: each family's sales earn its Scout Account
# a percentage, and the rest stays in a pack fund. Optionally the sales money itself is recorded
# coming in to the fund first; leave that off when the proceeds were already deposited there.
#
# Everything is recorded in one locked batch: either every line is written or none is.
class FundraiserCredit
  include ActiveModel::Model

  attr_accessor :name, :fund_id, :scout_share_percent, :record_proceeds, :admin
  attr_writer :sales

  Line = Data.define(:family, :sales, :share)

  validates :name, presence: true, length: { maximum: 120 }
  validate :fund_exists, :percent_is_valid, :sales_are_valid

  def sales
    (@sales || {}).to_h.transform_keys(&:to_s)
  end

  def record_proceeds?
    ActiveModel::Type::Boolean.new.cast(record_proceeds)
  end

  def fund
    @fund ||= Fund.find_by(id: fund_id)
  end

  def percent
    BigDecimal(scout_share_percent.to_s.strip.delete("%"))
  rescue ArgumentError
    nil
  end

  # One line per family that sold something, with what its Scout Account earns.
  def lines
    families = Family.where(id: sales.keys).index_by { |family| family.id.to_s }
    sales.filter_map do |family_id, input|
      family = families[family_id]
      money = Ledger.parse_dollars(input)
      next unless family && money&.positive?

      share = Money.new((money.fractional * percent / 100).round(0, BigDecimal::ROUND_HALF_UP).to_i)
      Line.new(family, money, share)
    end.sort_by { |line| line.family.name }
  end

  def total_sales
    lines.sum(Money.new(0), &:sales)
  end

  def total_scout_share
    lines.sum(Money.new(0), &:share)
  end

  def pack_share
    total_sales - total_scout_share
  end

  def save
    return false unless valid?

    batch = lines
    accounts = [ Ledger.external, fund.ledger_account, *batch.map { |line| line.family.ledger_account } ]
    DoubleEntry.lock_accounts(*accounts) do
      if record_proceeds?
        DoubleEntry.transfer(total_sales, from: Ledger.external, to: fund.ledger_account, code: :deposit,
                                          metadata: metadata("#{name}: sales proceeds"))
      end
      batch.each do |line|
        next unless line.share.positive?

        DoubleEntry.transfer(line.share, from: fund.ledger_account, to: line.family.ledger_account, code: :transfer,
                                         metadata: metadata("#{name}: #{percent_label} of #{line.sales.format} sales"))
      end
    end
    true
  rescue DoubleEntry::DoubleEntryError => error
    errors.add(:base, "The fundraiser couldn't be recorded (#{error.class.name.demodulize})")
    false
  end

  def percent_label
    "#{percent.to_s('F').delete_suffix('.0')}%"
  end

  private

  def metadata(memo)
    { memo: memo.truncate(200), admin_id: admin&.id }.compact
  end

  def fund_exists
    errors.add(:fund_id, "must be chosen") unless fund
  end

  def percent_is_valid
    errors.add(:scout_share_percent, "must be a number from 0 to 100") unless percent&.between?(0, 100)
  end

  def sales_are_valid
    invalid = sales.select { |_id, input| input.present? && Ledger.parse_dollars(input).nil? }
    if invalid.any?
      names = Family.where(id: invalid.keys).order(:name).pluck(:name)
      errors.add(:base, "Sales must be dollar amounts such as 25 or 25.50 (check #{names.to_sentence})")
    elsif errors.exclude?(:scout_share_percent) && lines.empty?
      errors.add(:base, "Enter sales for at least one family")
    end
  end
end
