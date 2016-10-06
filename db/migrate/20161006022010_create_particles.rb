class CreateParticles < ActiveRecord::Migration[4.2]
  def change
    create_table :particles do |t|
      t.belongs_to :game, index: true
      t.integer :team
      t.float :x
      t.float :y
      t.float :heading
      t.float :speed
      t.integer :power
      t.integer :lifetime
      t.boolean :remove
      t.timestamps
    end
  end
end
