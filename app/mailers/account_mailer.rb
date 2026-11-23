# Devise's mailer for Family accounts. A family has no email of its own, so its mail goes to the
# email addresses of its adults (Family#email_addresses).
class AccountMailer < Devise::Mailer
  default from: -> { ENV.fetch("MAIL_FROM", "Pack It In <no-reply@example.com>") }
  layout "mailer"
  helper :application

  protected

  # Devise addresses mail to `resource.email`, which a Family doesn't have.
  def headers_for(action, opts)
    resource.define_singleton_method(:email) { email_addresses }
    super
  end
end
