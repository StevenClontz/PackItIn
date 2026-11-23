# The app's only contact with Stripe: creating and looking up Checkout Sessions. Tests swap in a
# fake (OnlinePayment.gateway). Keys come from credentials (stripe: secret_key, webhook_secret) or
# the STRIPE_SECRET_KEY / STRIPE_WEBHOOK_SECRET environment variables.
class StripeGateway
  Session = Data.define(:id, :url, :paid, :payment_intent_id)

  def self.secret_key
    Rails.application.credentials.dig(:stripe, :secret_key) || ENV["STRIPE_SECRET_KEY"]
  end

  def self.webhook_secret
    Rails.application.credentials.dig(:stripe, :webhook_secret) || ENV["STRIPE_WEBHOOK_SECRET"]
  end

  def configured?
    self.class.secret_key.present?
  end

  def create_checkout_session(payment, success_url:, cancel_url:)
    line_items = [ line_item("Scout Account deposit for #{payment.family.name}", payment.amount_cents) ]
    line_items << line_item("Card processing fee", payment.fee_cents) if payment.fee_cents.positive?

    session = client.v1.checkout.sessions.create({
      mode: "payment",
      line_items: line_items,
      client_reference_id: payment.id.to_s,
      metadata: { online_payment_id: payment.id.to_s, family_id: payment.family_id.to_s },
      customer_email: payment.family.email_addresses.first,
      success_url: success_url,
      cancel_url: cancel_url
    }, { idempotency_key: "online-payment-#{payment.id}" })
    to_session(session)
  end

  def retrieve_checkout_session(id)
    to_session(client.v1.checkout.sessions.retrieve(id))
  end

  # Verifies a webhook's signature, raising Stripe::SignatureVerificationError if it isn't from Stripe.
  def construct_event(payload, signature)
    Stripe::Webhook.construct_event(payload, signature, self.class.webhook_secret.to_s)
  end

  private

  def client
    @client ||= Stripe::StripeClient.new(self.class.secret_key)
  end

  def line_item(name, cents)
    { quantity: 1, price_data: { currency: "usd", unit_amount: cents, product_data: { name: name } } }
  end

  def to_session(session)
    Session.new(id: session.id, url: session.url, paid: session.payment_status == "paid", payment_intent_id: session.payment_intent)
  end
end
