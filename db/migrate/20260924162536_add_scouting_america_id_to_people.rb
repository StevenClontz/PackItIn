class AddScoutingAmericaIdToPeople < ActiveRecord::Migration[8.1]
  def change
    add_column :people, :scouting_america_id, :string
  end
end
