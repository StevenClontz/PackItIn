# Preview at http://localhost:3000/rails/mailers/login_mailer
class LoginMailerPreview < ActionMailer::Preview
  def sign_in
    LoginMailer.sign_in(Family.email_login_eligible.first, "123456", "example-token")
  end
end
