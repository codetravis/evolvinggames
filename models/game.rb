class Game < ActiveRecord::Base
  has_many :units
  has_many :players
  has_many :particles
end
