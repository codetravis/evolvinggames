class CreateGames < ActiveRecord::Migration[4.2]
  def change
    create_table :games do |t|
      t.string :state
      t.integer :turn
      t.integer :max_turn
      t.timestamps
    end
  end
end
