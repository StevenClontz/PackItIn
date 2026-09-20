require "test_helper"

class LedgerTransactionTest < ActiveSupport::TestCase
  def build(from: :outside, to: families(:one), amount: "10.00", **attrs)
    LedgerTransaction.new({ from: ledger_ref(from), to: ledger_ref(to), amount: amount }.merge(attrs))
  end

  # Every transfer is two-sided, so all accounts (the outside world included) always sum to zero.
  def assert_ledger_balanced
    total = Family.all.sum { |family| family.balance.fractional } +
            Fund.all.sum { |fund| fund.balance.fractional } +
            Ledger.external.balance.fractional
    assert_equal 0, total
  end

  test "a deposit credits the account from outside the pack" do
    transaction = build(to: families(:one), amount: "50")
    assert transaction.save
    assert_equal :deposit, transaction.code
    assert_equal Money.new(50_00), families(:one).balance
    assert_equal Money.new(50_00), Ledger.total_held
    assert_ledger_balanced
  end

  test "a withdrawal debits the account to outside the pack" do
    transact from: :outside, to: funds(:general), dollars: 100
    transaction = build(from: funds(:general), to: :outside, amount: "30.25")

    assert transaction.save
    assert_equal :withdrawal, transaction.code
    assert_equal Money.new(69_75), funds(:general).balance
    assert_equal Money.new(69_75), Ledger.total_held
    assert_ledger_balanced
  end

  test "transfers move money between families and funds in every direction" do
    transact from: :outside, to: families(:one), dollars: 100
    transact from: :outside, to: funds(:general), dollars: 100

    [ [ families(:one), families(:two) ], [ families(:one), funds(:general) ],
      [ funds(:general), families(:two) ], [ funds(:general), funds(:campout) ] ].each do |from, to|
      transaction = build(from: from, to: to, amount: "5")
      assert transaction.save, "#{from.class} -> #{to.class}: #{transaction.errors.full_messages.to_sentence}"
      assert_equal :transfer, transaction.code
    end

    assert_equal Money.new(90_00), families(:one).balance
    assert_equal Money.new(10_00), families(:two).balance
    assert_equal Money.new(95_00), funds(:general).balance
    assert_equal Money.new(5_00), funds(:campout).balance
    assert_equal Money.new(200_00), Ledger.total_held, "transfers don't change what the pack holds"
    assert_ledger_balanced
  end

  test "each transaction writes two lines, one per account, that are partners" do
    assert_difference "DoubleEntry::Line.count", 2 do
      build(from: families(:one), to: funds(:general), amount: "20").save
    end

    debit = families(:one).ledger_lines.first
    credit = funds(:general).ledger_lines.first
    assert_equal Money.new(-20_00), debit.amount
    assert_equal Money.new(20_00), credit.amount
    assert_equal [ "fund", funds(:general).id.to_s ], [ debit[:partner_account], debit.partner_scope ]
    assert_equal [ "family", families(:one).id.to_s ], [ credit[:partner_account], credit.partner_scope ]
  end

  test "family accounts may go negative" do
    transaction = build(from: families(:one), to: :outside, amount: "15")
    assert transaction.save
    assert_equal Money.new(-15_00), families(:one).balance
    assert_equal Money.new(-15_00), Ledger.total_held
    assert_ledger_balanced
  end

  test "the memo and acting admin are stored with the ledger lines" do
    build(to: families(:one), memo: "Popcorn money", admin: families(:admin)).save

    metadata = families(:one).ledger_lines.first.metadata
    assert_equal "Popcorn money", metadata["memo"]
    assert_equal families(:admin).id, metadata["admin_id"]
  end

  test "the memo is optional" do
    assert build(memo: "").save
    assert_equal({}, families(:one).ledger_lines.first.metadata)
  end

  test "amounts accept dollar signs and thousands separators" do
    [ "$1,250.50", " 7 ", "0.05" ].each { |amount| assert build(amount: amount).valid?, amount }
    assert build(amount: "$1,250.50").save
    assert_equal Money.new(1_250_50), families(:one).balance
  end

  test "amount must be a positive dollar amount with at most two decimals" do
    [ "", nil, "abc", "0", "0.00", "-5", "1.234", "1e3", "12.", "1 000", "9999999999" ].each do |amount|
      transaction = build(amount: amount)
      assert_not transaction.valid?, amount.inspect
      assert transaction.errors[:amount].any?, amount.inspect
    end
  end

  test "both accounts are required and must exist" do
    [ "", nil, "nobody", "family:0", "fund:99999", "family:abc", "family:#{families(:one).id};drop" ].each do |ref|
      assert_not build(from: :outside).tap { |t| t.to = ref }.valid?, "to: #{ref.inspect}"
      assert_not build(to: families(:one)).tap { |t| t.from = ref }.valid?, "from: #{ref.inspect}"
    end
  end

  test "it needs at least one account inside the pack" do
    transaction = build(from: :outside, to: :outside)
    assert_not transaction.valid?
    assert_includes transaction.errors[:base], "Choose at least one account inside the pack"
  end

  test "money can't move from an account to itself" do
    [ families(:one), funds(:general) ].each do |account|
      transaction = build(from: account, to: account)
      assert_not transaction.valid?
      assert_includes transaction.errors[:to], "must be different from the From account"
    end
  end

  test "an invalid transaction records nothing" do
    assert_no_difference "DoubleEntry::Line.count" do
      assert_not build(amount: "abc").save
      assert_not build(from: :outside, to: :outside).save
      assert_not build(to: "family:0").save
    end
  end

  test "a failure inside the ledger records nothing and is reported" do
    transaction = build
    DoubleEntry.singleton_class.alias_method :original_transfer, :transfer
    DoubleEntry.define_singleton_method(:transfer) { |*| raise DoubleEntry::TransferNotAllowed, "boom" }

    assert_no_difference "DoubleEntry::Line.count" do
      assert_not transaction.save
    end
    assert_includes transaction.errors[:base], "The transaction couldn't be recorded (TransferNotAllowed)"
  ensure
    DoubleEntry.singleton_class.alias_method :transfer, :original_transfer
    DoubleEntry.singleton_class.remove_method :original_transfer
  end

  test "a long memo is rejected" do
    assert_not build(memo: "x" * 201).valid?
    assert build(memo: "x" * 200).valid?
  end

  test "subject is where the money ended up, or came from for a withdrawal" do
    assert_equal families(:one), build(to: families(:one)).subject
    assert_equal funds(:general), build(from: families(:one), to: funds(:general)).subject
    assert_equal funds(:general), build(from: funds(:general), to: :outside).subject
  end

  test "account options list outside, every family and every fund" do
    options = LedgerTransaction.account_options
    assert_equal [ "Outside the pack (money in or out)", "outside" ], options.first
    assert_includes options, [ "Scout Account: The Joneses", ledger_ref(families(:two)) ]
    assert_includes options, [ "Fund: Campout Fund", ledger_ref(funds(:campout)) ]
    assert_equal 1 + Family.count + Fund.count, options.size
  end
end
