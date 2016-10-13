class AddTeamColumnToUnits < ActiveRecord::Migration[4.2]
  def up
    add_column :units, :team, :integer
  end

  def down
    remove_column :units, :team
  end
end
