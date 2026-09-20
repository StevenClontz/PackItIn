class CreateFunds < ActiveRecord::Migration[8.1]
  def change
    create_table :funds do |t|
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :funds, :name, unique: true
  end
end
