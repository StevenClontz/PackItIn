class CreatePeople < ActiveRecord::Migration[8.1]
  def change
    create_table :people do |t|
      t.references :family, null: false, foreign_key: true
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.integer :position, null: false

      t.timestamps
    end
  end
end
