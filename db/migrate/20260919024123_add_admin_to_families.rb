class AddAdminToFamilies < ActiveRecord::Migration[8.1]
  def change
    add_column :families, :admin, :boolean, default: false, null: false
  end
end
