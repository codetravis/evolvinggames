class CreateUnits < ActiveRecord::Migration[4.2]
  def change
    create_table :units do |t|
      t.belongs_to :game, index: true
      t.belongs_to :player, index: true
      t.belongs_to :unit_type
      t.float :armor
      t.float :x
      t.float :y
      t.float :heading
      t.float :control_x
      t.float :control_y
      t.float :control_heading
      t.float :energy
      t.integer :turn
      t.integer :max_turn
      t.timestamps
    end
  end
end
