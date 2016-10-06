class ChangeUnitArmorAndTurn < ActiveRecord::Migration[4.2]
  def up
    change_column :units, :armor, :integer
    remove_column :units, :turn
    remove_column :units, :max_turn
  end

  def down
    change_column :units, :armor, :float
    add_column :units, :turn, :integer
    add_column :units, :max_turn, :integer
  end
end
