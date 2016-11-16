class Game < ActiveRecord::Base
  has_many :units
  has_many :players
  has_many :particles
  has_many :active_games
end
