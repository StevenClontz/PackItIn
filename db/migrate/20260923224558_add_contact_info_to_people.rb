class AddContactInfoToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :email, :string
    add_column :people, :phone_number, :string
    add_index :people, :email, unique: true
    add_index :people, :phone_number, unique: true
  end
end
