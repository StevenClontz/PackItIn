# The emailed sign-in code and link (Families::EmailLoginsController), sent to all of the family's
# adults at once. It's account mail, like password resets, so it goes out even to adults who
# unsubscribed from pack emails.
class LoginMailer < ApplicationMailer
  include ApplicationHelper # app_name, for the subject

  def sign_in(family, code, token)
    @family = family
    @code = code
    @link = email_login_link_url(token: token)
    mail to: family.email_addresses, subject: "Your #{app_name} sign-in code: #{code}"
  end
end
