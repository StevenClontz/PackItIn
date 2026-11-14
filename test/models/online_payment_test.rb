require "test_helper"

class OnlinePaymentTest < ActiveSupport::TestCase
  def payment(dollars = "50")
    families(:one).online_payments.create!(amount_dollars: dollars)
  end

  test "amounts must be dollars within the limits" do
    [ "", "abc", "4.99", "1000.01" ].each do |input|
      assert_not families(:one).online_payments.build(amount_dollars: input).valid?, input.inspect
    end
    assert families(:one).online_payments.build(amount_dollars: "1,000").valid?
  end

  test "completing credits the Scout Account exactly once" do
    online_payment = payment("50")

    assert online_payment.complete!(payment_intent_id: "pi_1")
    assert_not online_payment.complete!(payment_intent_id: "pi_1")

    assert online_payment.reload.completed?
    assert_equal Money.new(5000), families(:one).balance
    line = families(:one).ledger_lines.first
    assert_equal :deposit, line.code
    assert_equal "Online payment (card)", line.metadata["memo"]
  end

  test "no fee by default" do
    assert_equal 0, payment.fee_cents
  end

  test "a configured fee is grossed up so the pack nets the deposit" do
    ENV["ONLINE_PAYMENT_FEE_PERCENT"] = "2.9"
    ENV["ONLINE_PAYMENT_FEE_CENTS"] = "30"
    online_payment = payment("100")
    # Stripe takes 2.9% + 30c of the total; what's left must cover the $100 deposit.
    assert_equal 330, online_payment.fee_cents
    assert_operator (online_payment.total_cents * 0.971) - 30, :>=, 10_000
  ensure
    ENV.delete("ONLINE_PAYMENT_FEE_PERCENT")
    ENV.delete("ONLINE_PAYMENT_FEE_CENTS")
  end
end
