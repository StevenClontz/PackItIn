require "test_helper"

class FundTest < ActiveSupport::TestCase
  test "valid with a name" do
    assert Fund.new(name: "Popcorn").valid?
  end

  test "requires a name" do
    fund = Fund.new(name: "")
    assert_not fund.valid?
    assert_includes fund.errors[:name], "can't be blank"
  end

  test "name must be unique, ignoring case" do
    fund = Fund.new(name: funds(:general).name.upcase)
    assert_not fund.valid?
    assert_includes fund.errors[:name], "has already been taken"
  end

  test "description is optional" do
    assert Fund.new(name: "Popcorn", description: nil).valid?
  end

  test "a new fund has a zero balance and no activity" do
    assert_equal Money.new(0), funds(:general).balance
    assert_not funds(:general).ledger_activity?
    assert_empty funds(:general).ledger_lines
  end

  test "balance follows the ledger" do
    transact from: :outside, to: funds(:general), dollars: "125.50"
    assert_equal Money.new(125_50), funds(:general).balance
  end

  test "a fund with no activity can be destroyed" do
    assert_difference "Fund.count", -1 do
      assert funds(:general).destroy
    end
  end

  test "a fund with activity can't be destroyed" do
    transact from: :outside, to: funds(:general), dollars: 10

    assert_no_difference "Fund.count" do
      assert_not funds(:general).destroy
    end
    assert_includes funds(:general).errors.full_messages, "General has account activity and can't be deleted"
    assert_equal Money.new(10_00), funds(:general).reload.balance
  end

  test "an unsaved fund has a zero balance" do
    assert_equal Money.new(0), Fund.new(name: "Popcorn").balance
  end
end
