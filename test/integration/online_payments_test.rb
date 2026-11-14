require "test_helper"

class OnlinePaymentsTest < ActionDispatch::IntegrationTest
  def sign_in_as(username, password: "password123")
    post family_session_path, params: { family: { login: username, password: password } }
  end

  def start_payment(dollars = "40")
    post family_online_payments_path(families(:one)), params: { online_payment: { amount_dollars: dollars } }
    OnlinePayment.last
  end

  test "a family adds money: checkout, return page, credited balance" do
    sign_in_as "examplefamily"
    get family_account_path(families(:one))
    assert_select "a[href=?]", new_family_online_payment_path(families(:one))

    get new_family_online_payment_path(families(:one))
    assert_response :success

    payment = start_payment("40")
    assert_redirected_to "https://checkout.stripe.test/#{payment.id}"
    assert_equal "cs_test_#{payment.id}", payment.stripe_checkout_session_id
    assert payment.pending?

    @stripe.paid = true
    get family_online_payment_path(families(:one), payment)
    assert_redirected_to family_account_path(families(:one))
    follow_redirect!
    assert_match "$40.00 was added", response.body
    assert_equal Money.new(4000), families(:one).balance
  end

  test "returning before payment clears doesn't credit anything" do
    sign_in_as "examplefamily"
    payment = start_payment
    get family_online_payment_path(families(:one), payment)
    follow_redirect!
    assert_match "processing", response.body
    assert payment.reload.pending?
    assert_equal Money.new(0), families(:one).balance
  end

  test "an invalid amount re-renders the form" do
    sign_in_as "examplefamily"
    assert_no_difference "OnlinePayment.count" do
      post family_online_payments_path(families(:one)), params: { online_payment: { amount_dollars: "2" } }
    end
    assert_response :unprocessable_content
    assert_empty @stripe.created
  end

  test "a Stripe outage is reported and leaves no pending payment" do
    @stripe.error = Stripe::APIConnectionError.new("down")
    sign_in_as "examplefamily"
    assert_no_difference "OnlinePayment.count" do
      start_payment
    end
    assert_redirected_to new_family_online_payment_path(families(:one))
  end

  test "families can't add money to, or view payments of, another family" do
    sign_in_as "joneses"
    get new_family_online_payment_path(families(:one))
    assert_redirected_to root_path

    post family_online_payments_path(families(:one)), params: { online_payment: { amount_dollars: "40" } }
    assert_redirected_to root_path
    assert_empty @stripe.created

    payment = families(:one).online_payments.create!(amount_dollars: "40", stripe_checkout_session_id: "cs_x")
    @stripe.paid = true
    get family_online_payment_path(families(:one), payment)
    assert_redirected_to root_path
    assert payment.reload.pending?
  end

  test "the Add money button is hidden when Stripe isn't configured" do
    OnlinePayment.gateway = StripeGateway.new
    sign_in_as "examplefamily"
    get family_account_path(families(:one))
    assert_select "a", text: "Add money", count: 0

    get new_family_online_payment_path(families(:one))
    assert_redirected_to family_account_path(families(:one))
  end

  # --- webhooks ---

  test "a signed checkout.session.completed webhook credits the account once" do
    payment = families(:one).online_payments.create!(amount_dollars: "25", stripe_checkout_session_id: "cs_hook")
    payload, signature = FakeStripeGateway.signed_webhook("checkout.session.completed", "cs_hook")

    2.times do
      post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => signature, "Content-Type" => "application/json" }
      assert_response :ok
    end

    assert payment.reload.completed?
    assert_equal "pi_test", payment.stripe_payment_intent_id
    assert_equal Money.new(2500), families(:one).balance
  end

  test "an unpaid completion (e.g. bank transfer pending) waits for async success" do
    payment = families(:one).online_payments.create!(amount_dollars: "25", stripe_checkout_session_id: "cs_async")
    payload, signature = FakeStripeGateway.signed_webhook("checkout.session.completed", "cs_async", payment_status: "unpaid")
    post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => signature, "Content-Type" => "application/json" }
    assert payment.reload.pending?

    payload, signature = FakeStripeGateway.signed_webhook("checkout.session.async_payment_succeeded", "cs_async")
    post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => signature, "Content-Type" => "application/json" }
    assert payment.reload.completed?
  end

  test "expired sessions are marked expired" do
    payment = families(:one).online_payments.create!(amount_dollars: "25", stripe_checkout_session_id: "cs_old")
    payload, signature = FakeStripeGateway.signed_webhook("checkout.session.expired", "cs_old", payment_status: "unpaid")
    post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => signature, "Content-Type" => "application/json" }
    assert payment.reload.expired?
  end

  test "unsigned or forged webhooks are rejected" do
    payment = families(:one).online_payments.create!(amount_dollars: "25", stripe_checkout_session_id: "cs_forged")
    payload, = FakeStripeGateway.signed_webhook("checkout.session.completed", "cs_forged")

    post stripe_webhook_path, params: payload, headers: { "Content-Type" => "application/json" }
    assert_response :bad_request
    post stripe_webhook_path, params: payload, headers: { "Stripe-Signature" => "t=1,v1=bad", "Content-Type" => "application/json" }
    assert_response :bad_request

    assert payment.reload.pending?
    assert_equal Money.new(0), families(:one).balance
  end
end
