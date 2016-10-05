class CreatePlayers < ActiveRecord::Migration[4.2]
  def change
    create_table :players do |t|
      t.string :username
      t.string :password
      t.timestamps
    end
  end
end
