# Stripe's notifications about Checkout Sessions. Not an ApplicationController: Stripe isn't a browser
# (allow_browser would turn it away) and sends no CSRF token; the signature authenticates it instead.
class StripeWebhooksController < ActionController::Base
  skip_forgery_protection

  def create
    event = OnlinePayment.gateway.construct_event(request.raw_post, request.headers["Stripe-Signature"])
    session = event.data.object

    case event.type
    when "checkout.session.completed", "checkout.session.async_payment_succeeded"
      payment(session)&.complete!(payment_intent_id: session.payment_intent) if session.payment_status == "paid"
    when "checkout.session.expired", "checkout.session.async_payment_failed"
      payment(session)&.then { |payment| payment.expired! if payment.pending? }
    end

    head :ok
  rescue JSON::ParserError, Stripe::SignatureVerificationError
    head :bad_request
  end

  private

  def payment(session)
    OnlinePayment.find_by(stripe_checkout_session_id: session.id)
  end
end
