# "Add money": a family paying into its Scout Account by card through Stripe Checkout.
class OnlinePaymentsController < ApplicationController
  before_action :authenticate_family!
  before_action :set_family
  before_action :require_enabled

  def new
    @online_payment = @family.online_payments.build
    authorize! :create, @online_payment
  end

  def create
    @online_payment = @family.online_payments.build(amount_dollars: params.dig(:online_payment, :amount_dollars))
    authorize! :create, @online_payment
    return render(:new, status: :unprocessable_content) unless @online_payment.save

    session = OnlinePayment.gateway.create_checkout_session(
      @online_payment,
      success_url: family_online_payment_url(@family, @online_payment),
      cancel_url: new_family_online_payment_url(@family)
    )
    @online_payment.update!(stripe_checkout_session_id: session.id)
    redirect_to session.url, allow_other_host: true, status: :see_other
  rescue Stripe::StripeError => error
    Rails.logger.error("Stripe checkout failed: #{error.message}")
    @online_payment.destroy if @online_payment&.persisted?
    redirect_to new_family_online_payment_path(@family), alert: "We couldn't reach the payment processor. Please try again.", status: :see_other
  end

  # Where Stripe sends the family back. The webhook usually completes the payment first; if it hasn't
  # yet, ask Stripe directly so the balance is right when the family lands on its statement.
  def show
    @online_payment = @family.online_payments.find(params[:id])
    authorize! :read, @online_payment

    if @online_payment.pending? && @online_payment.stripe_checkout_session_id
      session = OnlinePayment.gateway.retrieve_checkout_session(@online_payment.stripe_checkout_session_id)
      @online_payment.complete!(payment_intent_id: session.payment_intent_id) if session.paid
    end

    if @online_payment.reload.completed?
      redirect_to family_account_path(@family), notice: "Thanks! #{Money.new(@online_payment.amount_cents).format} was added to your Scout Account."
    else
      redirect_to family_account_path(@family), notice: "Your payment is processing. It will show on your statement once it clears."
    end
  rescue Stripe::StripeError
    redirect_to family_account_path(@family), notice: "Your payment is processing. It will show on your statement once it clears."
  end

  private

  def set_family
    @family = Family.find(params[:family_id])
  end

  def require_enabled
    redirect_to family_account_path(@family), alert: "Online payments aren't set up yet." unless OnlinePayment.enabled?
  end
end
