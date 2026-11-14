# Stands in for Stripe in tests: sessions are recorded, not created. Webhook signatures are still
# checked for real (StripeGateway#construct_event), against WEBHOOK_SECRET.
class FakeStripeGateway < StripeGateway
  WEBHOOK_SECRET = "whsec_test"

  attr_accessor :paid, :error
  attr_reader :created

  def initialize
    @created = []
    @paid = false
  end

  def configured? = true

  def create_checkout_session(payment, success_url:, cancel_url:)
    raise error if error

    @created << { payment:, success_url:, cancel_url: }
    Session.new(id: "cs_test_#{payment.id}", url: "https://checkout.stripe.test/#{payment.id}", paid: false, payment_intent_id: nil)
  end

  def retrieve_checkout_session(id)
    Session.new(id:, url: nil, paid: paid, payment_intent_id: ("pi_test" if paid))
  end

  # A webhook body and Stripe-Signature header, signed as Stripe would sign them.
  def self.signed_webhook(type, session_id, payment_status: "paid")
    payload = { id: "evt_test", object: "event", type: type,
                data: { object: { id: session_id, object: "checkout.session", payment_status: payment_status, payment_intent: "pi_test" } } }.to_json
    timestamp = Time.now
    signature = Stripe::Webhook::Signature.compute_signature(timestamp, payload, WEBHOOK_SECRET)
    [ payload, Stripe::Webhook::Signature.generate_header(timestamp, signature) ]
  end
end
