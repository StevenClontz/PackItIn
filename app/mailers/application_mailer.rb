class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAIL_FROM", "Pack It In <no-reply@example.com>") }
  layout "mailer"
  helper :application, :events
end
