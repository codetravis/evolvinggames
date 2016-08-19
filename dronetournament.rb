require 'pg'
require 'date'

class DroneTournament

  def initialize()
      @db_connection = PG.connect(dbname: 'dronetournament')
  end

  def sign_in(username)
    player = @db_connection.exec("SELECT * FROM Players WHERE username = '#{username}'")
    if player.ntuples().zero?
      player = @db_connection.exec("INSERT INTO Players (username) VALUES ('#{username}') RETURNING *")
    end

    player = player[0]

    { "action" => "Sign In", "player_id" => player["id"] }
  end

  def list_games(player_id)
    games = @db_connection.exec("SELECT * FROM ActiveGames WHERE player_id='#{player_id}'")
    if games.ntuples().zero?
      create_new_game(player_id)
      games = @db_connection.exec("SELECT * FROM ActiveGames WHERE player_id='#{player_id}'")
    end

    game_list = []

    games.each do |game|
      opponent = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id='#{game["game_id"]}' AND player_id != '#{player_id}'")
      if opponent.ntuples().zero?
        game["opponent"] = ""
      else
        game["opponent"] = opponent[0]["player_id"]
      end
      game_list.push(game)
    end

    {"action" => "List Games", "games" => game_list}
  end

  def get_game(game_id)
    game = @db_connection.exec("SELECT * FROM Games WHERE id='#{game_id}'")
    current_game = game[0].to_h
    current_game["units"] = get_units(game_id)
    current_game["players"] = get_players(game_id)
    current_game["types"] = get_types()
    current_game["action"] = "Load Game"
    current_game
  end

  def get_units(game_id)
    units = @db_connection.exec("SELECT * FROM Units WHERE game_id='#{game_id}'")
    all_units = units.to_a
  end

  def get_players(game_id)
    players = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id='#{game_id}'")
    all_players = players.to_a
  end

  def get_types()
    types = @db_connection.exec("SELECT * FROM Types")
    types = types.to_a
  end

  def create_new_game(player_id)
    game = @db_connection.exec("INSERT INTO Games (state, created, turn, max_turns) VALUES ('build', NOW(), 1, 30) RETURNING *")
    game = game[0]
    @db_connection.exec("INSERT INTO ActiveGames (game_id, player_number, player_id, player_state, turn, state_updated) VALUES ('#{game["id"]}', 1, '#{player_id}', 'plan', 1, NOW())")
    @db_connection.exec("INSERT INTO ActiveGames (game_id, player_number, player_id, player_state, turn, state_updated) VALUES ('#{game["id"]}', 2, 0, 'empty', 1, NOW())")
    unit_one_info = { game_id: game["id"], player_id: player_id, armor: 5, x: 100, y: 100,
                  heading: -30, energy: 0, type: "T-Fighter", team: 1}
    unit_two_info = { game_id: game["id"], player_id: 0, armor: 2, x: 200, y: 250,
                  heading: 30, energy: 0, type: "Eye-Fighter", team: 2}
    create_new_unit(unit_one_info)
    create_new_unit(unit_two_info)
    game
  end

  def create_new_unit(unit_info)
    insert_statement = "INSERT INTO Units (game_id, player_id, armor, x, y, heading, control_x, control_y, control_heading, energy, type, team) "
    insert_statement += "VALUES (#{unit_info[:game_id]}, #{unit_info[:player_id]}, #{unit_info[:armor]}, " +
      "#{unit_info[:x]}, #{unit_info[:y]}, #{unit_info[:heading]}, " +
      "#{unit_info[:x]}, #{unit_info[:y]}, #{unit_info[:heading]}, " +
      "#{unit_info[:energy]}, '#{unit_info[:type]}', #{unit_info[:team]}) "
    insert_statement += "RETURNING *"
    new_unit = @db_connection.exec(insert_statement)
    new_unit = new_unit[0]
  end

  def join_game(player_id)
    empty_games = @db_connection.exec("SELECT * FROM ActiveGames WHERE player_state='empty'")
    if empty_games.ntuples().zero?
      list_games(player_id)
    else
      game_id = 0
      empty_games.each do |game|
        game_id = game["game_id"]
        puts game
        puts game_id
        other_player = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id=#{game_id} AND player_state!='empty'")
        if (other_player[0]["player_id"] == player_id)
          next
        else
          new_player = @db_connection.exec("UPDATE ActiveGames SET player_id=#{player_id}, player_state='plan' WHERE game_id=#{game_id} AND player_state='empty' RETURNING *")
          @db_connection.exec("UPDATE Units SET player_id=#{player_id} WHERE game_id=#{game_id} AND player_id=0")
          break
        end
      end
      get_game(game_id)
    end
  end

  def end_turn(game_id, move_requests)
    player_id = move_requests["player_id"]
    current_player = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id=#{game_id} AND player_id=#{player_id} ")
    current_player = current_player[0]
    other_players = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id=#{game_id} AND player_id!=#{player_id} ")

    game = get_game(game_id)

    action = "Turn Ended"
    other_players.each do |player|
      if (player["turn"].to_i < current_player["turn"].to_i ||
          (player["turn"].to_i == current_player["turn"].to_i && player["player_state"] == "finished"))
        action = "Turn Stop"
      end
    end

    if (game["turn"].to_i < current_player["turn"].to_i)
      action = "Turn Stop"
    end

    if action == "Turn Ended"
      new_turn = current_player["turn"].to_i + 1
      set_player_state(game_id, player_id, 'finished', new_turn)
      move_requests["moves"].each do |move|
        if move["x"] == "null"
          move["x"] = 1
          move["y"] = 1
          move["heading"] = 1
        end
        puts move
        @db_connection.exec("UPDATE Units SET control_x=#{move["control-x"]}, control_y=#{move["control-y"]}, control_heading=#{move["control-heading"]} WHERE player_id=#{player_id} AND id=#{move["unit_id"]}");
      end
    end
    {action: action}
  end

  def next_turn(game_id, player_id)
    current_player = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id='#{game_id}' AND player_id=#{player_id}")
    current_player = current_player[0]

    other_players = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id='#{game_id}' AND player_id!=#{player_id}")
    game = get_game(game_id)
    action = "Ready"
    first_action = 0

    if current_player["player_state"] != "finished"
      action = "Waiting"
    else
      other_players.each do |player|
        if DateTime.parse(player["state_updated"]).to_time.to_i < first_action || first_action == 0
          first_action = DateTime.parse(player["state_updated"]).to_time.to_i
        end

        if current_player["turn"].to_i > player["turn"].to_i
          action = "Waiting"
        end
      end
    end

    puts "Now         : " + Time.now.to_i.to_s
    puts "First Action: " + first_action.to_s
    # if Time.now.to_i - first_action > 600
    #   action = "Ready"
    # end

    if action == "Ready"
      units = get_units(game_id)
      set_player_state(game_id, player_id, "updated", current_player["turn"])
    end

    { action: action, units: units }
  end

  def update_unit_positions(game_id)
    units = get_units(game_id)
    units.each do |unit|
      control_defaults = get_new_control_defaults(unit)
      @db_connection.exec("UPDATE Units SET x=#{unit["control_x"]}, y=#{unit["control_y"]}, heading=#{unit["control_heading"]}, control_x=#{control_defaults[:x]}, control_y=#{control_defaults[:y]}, control_heading=#{control_defaults[:heading]} WHERE id=#{unit["id"]}");
    end
  end

  def get_new_control_defaults(unit)
    type = get_type(unit["type"])
    new_x = unit["control_x"].to_f + (type["speed"].to_f * Math.cos(unit["control_heading"].to_f/Math::PI))
    new_y = unit["control_y"].to_f + (type["speed"].to_f * Math.sin(unit["control_heading"].to_f/Math::PI))

    {x: new_x, y: new_y, heading: unit["control_heading"].to_f}
  end

  def calculate_new_heading(unit)
    type = get_type(unit["type"])
    current_heading = unit["heading"].to_f
    start_x = unit["x"].to_f
    start_y = unit["y"].to_f
    goal_x = unit["control-x"].to_f
    goal_y = unit["control-y"].to_f
    distance = type["speed"].to_f/30
    max_turn = type["turn"].to_f
    start_angle = unit["heading"].to_f
    goal_angle = Math.atan2(goal_y - start_y, goal_x - start_x)
    30.times do
      # TODO -- add server side calculation for final point
    end
  end

  def get_type(type_name)
    type = @db_connection.exec("SELECT * FROM Types WHERE name='#{type_name}'")
    type = type[0]
  end

  def set_player_state(game_id, player_id, state, next_turn)
    @db_connection.exec("UPDATE ActiveGames SET player_state='#{state}', state_updated=NOW(), turn=#{next_turn} WHERE game_id=#{game_id} AND player_id=#{player_id}")
  end

  def check_all_players_ready(game_id, player_id)
    current_player = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id='#{game_id}' AND player_id=#{player_id}")
    current_player = current_player[0]

    other_players = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id='#{game_id}' AND player_id!=#{player_id}")

    action = "Update Ready"
    other_players.each do |player|
      if (player["turn"] < current_player["turn"] || (player["turn"] == current_player["turn"] && player["player_state"] == "finished"))
        action = "Update Waiting"
      end
    end

    if action == "Update Ready"
      game = get_game(game_id)
      if game["turn"].to_i < current_player["turn"].to_i
        next_turn = game["turn"].to_i + 1
        @db_connection.exec("UPDATE Games SET turn=#{next_turn} WHERE id=#{game_id}")
        update_unit_positions(game_id)
      end

      set_player_state(game_id, player_id, 'plan', current_player["turn"])
    end

    {action: action}
  end


  def drop_tables()
    @db_connection.exec("DROP TABLE IF EXISTS Games")
    @db_connection.exec("DROP TABLE IF EXISTS Players")
    @db_connection.exec("DROP TABLE IF EXISTS ActiveGames")
    @db_connection.exec("DROP TABLE IF EXISTS Units")
    @db_connection.exec("DROP TABLE IF EXISTS Types")
    @db_connection.exec("DROP TABLE IF EXISTS Particles")
  end

  def setup_tables()
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Games(id SERIAL, state VARCHAR(20), turn INTEGER, max_turns INTEGER, created TIMESTAMP)")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Players(id SERIAL, username VARCHAR(50))")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS ActiveGames(game_id INTEGER, player_number INTEGER, player_id INTEGER, player_state VARCHAR(20), turn INTEGER, state_updated TIMESTAMP)")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Units(id SERIAL, game_id INTEGER, player_id INTEGER, armor FLOAT, x FLOAT, y FLOAT, heading FLOAT, control_x FLOAT, control_y FLOAT, control_heading FLOAT, energy FLOAT, type VARCHAR(30), team INTEGER)")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Types(id SERIAL, name VARCHAR(20), speed FLOAT, turn FLOAT, armor FLOAT, full_energy FLOAT, charge_energy FLOAT, image VARCHAR(20))")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Particles(id SERIAL, game_id INTEGER, team INTEGER, x FLOAT, y FLOAT, heading FLOAT, speed FLOAT, power FLOAT)")
    load_types()
  end

  def load_types()
    types_statement = "INSERT INTO Types (name, speed, turn, armor, full_energy, charge_energy, image) VALUES "
    types_statement += "('T-Fighter', 120, 4, 5, 100, 5, 't_fighter.png'), "
    types_statement += "('Eye-Fighter', 90, 3, 2, 100, 4, 'eye_fighter.png') "

    @db_connection.exec(types_statement)
  end

end
