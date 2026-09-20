class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :title, null: false
      t.text :description
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false
      t.datetime :rsvp_deadline_at

      t.timestamps
    end
    add_index :events, :starts_at
  end
end
