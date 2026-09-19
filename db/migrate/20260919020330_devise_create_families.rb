# frozen_string_literal: true

class DeviseCreateFamilies < ActiveRecord::Migration[8.1]
  def change
    create_table :families do |t|
      ## Database authenticatable
      t.string :username,           null: false
      t.string :encrypted_password, null: false, default: ""

      ## Rememberable
      t.datetime :remember_created_at

      t.timestamps null: false
    end

    add_index :families, :username, unique: true
  end
end
