class RenamePositionToDenOnPeople < ActiveRecord::Migration[8.1]
  def change
    rename_column :people, :position, :den
  end
end
