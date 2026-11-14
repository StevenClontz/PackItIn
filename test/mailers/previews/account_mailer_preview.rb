# Preview at http://localhost:3000/rails/mailers/account_mailer
class AccountMailerPreview < ActionMailer::Preview
  def reset_password_instructions
    AccountMailer.reset_password_instructions(Family.first, "example-token")
  end
end
