class CreateRsvps < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvps do |t|
      t.references :event, null: false, foreign_key: true
      t.references :person, null: false, foreign_key: true
      t.integer :status, null: false

      t.timestamps
    end
    add_index :rsvps, %i[event_id person_id], unique: true
  end
end
