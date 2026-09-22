class AddPasswordOnlyToFamilies < ActiveRecord::Migration[8.1]
  def change
    add_column :families, :password_only, :boolean, default: false, null: false
  end
end
