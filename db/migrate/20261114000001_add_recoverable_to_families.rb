class AddRecoverableToFamilies < ActiveRecord::Migration[8.1]
  def change
    add_column :families, :reset_password_token, :string
    add_column :families, :reset_password_sent_at, :datetime
    add_index :families, :reset_password_token, unique: true
  end
end
