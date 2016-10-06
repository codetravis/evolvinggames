class CreateUnitTypes < ActiveRecord::Migration[4.2]
  def change
    create_table :unit_types do |t|
      t.string :name
      t.float :speed
      t.float :turn
      t.integer :armor
      t.float :full_energy
      t.float :charge_energy
      t.string :image_name
    end
  end
end
