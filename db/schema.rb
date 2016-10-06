# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161006022010) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_games", force: :cascade do |t|
    t.integer  "player_number"
    t.integer  "player_id"
    t.integer  "game_id"
    t.string   "player_state"
    t.integer  "player_turn"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["game_id"], name: "index_active_games_on_game_id", using: :btree
    t.index ["player_id"], name: "index_active_games_on_player_id", using: :btree
  end

  create_table "games", force: :cascade do |t|
    t.string   "state"
    t.integer  "turn"
    t.integer  "max_turn"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "particles", force: :cascade do |t|
    t.integer  "game_id"
    t.integer  "team"
    t.float    "x"
    t.float    "y"
    t.float    "heading"
    t.float    "speed"
    t.integer  "power"
    t.integer  "lifetime"
    t.boolean  "remove"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["game_id"], name: "index_particles_on_game_id", using: :btree
  end

  create_table "players", force: :cascade do |t|
    t.string   "username"
    t.string   "password"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "unit_types", force: :cascade do |t|
    t.string  "name"
    t.float   "speed"
    t.float   "turn"
    t.integer "armor"
    t.float   "full_energy"
    t.float   "charge_energy"
    t.string  "image_name"
  end

  create_table "units", force: :cascade do |t|
    t.integer  "game_id"
    t.integer  "player_id"
    t.integer  "unit_type_id"
    t.float    "armor"
    t.float    "x"
    t.float    "y"
    t.float    "heading"
    t.float    "control_x"
    t.float    "control_y"
    t.float    "control_heading"
    t.float    "energy"
    t.integer  "turn"
    t.integer  "max_turn"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["game_id"], name: "index_units_on_game_id", using: :btree
    t.index ["player_id"], name: "index_units_on_player_id", using: :btree
  end

end
