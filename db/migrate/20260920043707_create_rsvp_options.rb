class CreateRsvpOptions < ActiveRecord::Migration[8.1]
  def change
    create_table :rsvp_options do |t|
      t.references :event, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description

      t.timestamps
    end
    add_index :rsvp_options, %i[event_id name], unique: true
  end
end
