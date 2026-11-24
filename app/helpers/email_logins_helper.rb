module EmailLoginsHelper
  # "s**@example.com": enough to tell which inbox to check, without showing the address to anyone
  # who picks the family on the sign-in page.
  def masked_email(email)
    local, domain = email.to_s.split("@", 2)
    "#{local[0]}#{'*' * [ local.length - 1, 2 ].max}@#{domain}"
  end
end
