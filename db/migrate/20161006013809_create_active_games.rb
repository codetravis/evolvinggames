class CreateActiveGames < ActiveRecord::Migration[4.2]
  def change
    create_table :active_games do |t|
      t.integer :player_number
      t.belongs_to :player, index: true
      t.belongs_to :game, index: true
      t.string :player_state
      t.integer :player_turn
      t.timestamps
    end
  end
end
