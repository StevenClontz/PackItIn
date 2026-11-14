require "test_helper"

class FundraiserCreditTest < ActiveSupport::TestCase
  def credit(**attrs)
    FundraiserCredit.new({ name: "Popcorn", fund_id: funds(:general).id, scout_share_percent: "35", record_proceeds: "1",
                           sales: { families(:one).id => "100", families(:two).id => "45.50", families(:three).id => "" } }.merge(attrs))
  end

  test "computes each family's share, rounding to the cent" do
    lines = credit.lines.index_by(&:family)
    assert_equal 2, lines.size
    assert_equal Money.new(3500), lines[families(:one)].share
    assert_equal Money.new(1593), lines[families(:two)].share # 35% of $45.50 = $15.925
    assert_equal Money.new(14550), credit.total_sales
    assert_equal Money.new(14550 - 5093), credit.pack_share
  end

  test "records proceeds into the fund and shares out to Scout Accounts" do
    fund = funds(:general)
    before = fund.balance
    assert credit.save

    assert_equal Money.new(3500), families(:one).balance
    assert_equal Money.new(1593), families(:two).balance
    assert_equal before + Money.new(14550 - 5093), fund.balance
    assert_equal "Popcorn: 35% of $100.00 sales", families(:one).ledger_lines.first.metadata["memo"]
  end

  test "without recording proceeds, shares come out of what's already in the fund" do
    fund = funds(:general)
    before = fund.balance
    assert credit(record_proceeds: "0").save
    assert_equal before - Money.new(5093), fund.balance
  end

  test "validates the inputs" do
    assert_not credit(name: "").valid?
    assert_not credit(fund_id: nil).valid?
    assert_not credit(scout_share_percent: "120").valid?
    assert_not credit(scout_share_percent: "lots").valid?
    assert_not credit(sales: { families(:one).id => "" }).valid?

    bad = credit(sales: { families(:one).id => "ten dollars" })
    assert_not bad.valid?
    assert_match "The Example Family", bad.errors.full_messages.to_sentence
  end

  test "a 0% share still records the proceeds" do
    assert credit(scout_share_percent: "0").save
    assert_equal Money.new(0), families(:one).balance
  end
end
