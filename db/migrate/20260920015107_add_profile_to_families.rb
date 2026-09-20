class AddProfileToFamilies < ActiveRecord::Migration[8.1]
  # Temporary defaults let NOT NULL columns be added to existing rows; they are dropped below so new
  # records must supply real values. Existing families get placeholders and must edit their profile.
  def change
    add_column :families, :name, :string, null: false, default: ""
    add_column :families, :street_address, :string, null: false, default: ""
    add_column :families, :city, :string, null: false, default: ""
    add_column :families, :state, :integer, null: false, default: 0
    add_column :families, :zip, :string, null: false, default: ""

    reversible do |dir|
      dir.up { execute "UPDATE families SET name = username" }
    end

    change_column_default :families, :name, from: "", to: nil
    change_column_default :families, :street_address, from: "", to: nil
    change_column_default :families, :city, from: "", to: nil
    change_column_default :families, :state, from: 0, to: nil
    change_column_default :families, :zip, from: "", to: nil
  end
end
