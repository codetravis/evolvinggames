class AddSaltToPlayers < ActiveRecord::Migration[5.0]
  def change
    add_column :players, :salt, :string
  end
end
