class Player < ActiveRecord::Base
  has_many :active_games
  has_many :units
end
