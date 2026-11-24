class ReplaceAddressLoginWithEmailLogin < ActiveRecord::Migration[8.1]
  def change
    # Only existed to opt a family out of address login, which is gone.
    remove_column :families, :password_only, :boolean, default: false, null: false

    # The family's pending emailed sign-in code (see Family#start_email_login!).
    add_column :families, :login_code_digest, :string
    add_column :families, :login_code_sent_at, :datetime
    add_column :families, :login_code_attempts, :integer, default: 0, null: false
  end
end
