class CreateLeaderships < ActiveRecord::Migration[8.1]
  def change
    create_table :leaderships do |t|
      t.references :person, null: false, foreign_key: true
      t.integer :role, null: false
      t.integer :den # only for den roles (Den Leader, Assistant Den Leader)
      t.timestamps
    end
    # SQLite treats NULL dens as distinct, so this only guards den roles; Leadership's
    # uniqueness validation covers pack-wide ones.
    add_index :leaderships, %i[person_id role den], unique: true
  end
end
