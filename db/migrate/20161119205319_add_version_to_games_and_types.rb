class AddVersionToGamesAndTypes < ActiveRecord::Migration[5.0]
  def change
    add_column :games, :version, :string
    add_column :unit_types, :version, :string
  end
end
