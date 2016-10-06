class Unit < ActiveRecord::Base
  belongs_to :game
  belongs_to :player
  belongs_to :unit_type
end
