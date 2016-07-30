require 'pg'

class DroneTournament

  def initialize()
      @db_connection = PG.connect(dbname: 'dronetournament')
  end

  def sign_in(username)
    puts username
    player = @db_connection.exec("SELECT * FROM Players WHERE username = '#{username}'")
    if player.ntuples().zero?
      player = @db_connection.exec("INSERT INTO Players (username) VALUES ('#{username}') RETURNING *")
    end

    player = player[0]

    { "action" => "Sign In", "player_id" => player["id"] }
  end

  def list_games(player_id)
    games = @db_connection.exec("SELECT * FROM ActiveGames WHERE player_id = '#{player_id}'")
    if games.ntuples().zero?
      create_new_game(player_id)
      games = @db_connection.exec("SELECT * FROM ActiveGames WHERE player_id = '#{player_id}'")
    end

    game_list = []

    games.each do |game|
      opponent = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id = '#{game["game_id"]}' AND player_id != '#{player_id}'")
      if opponent.ntuples().zero?
        game["opponent"] = ""
      else
        game["opponent"] = opponent["player_id"]
      end
      game_list.push(game)
    end

    {"action" => "List Games", "games" => game_list}
  end

  def get_game(game_id)
    game = @db_connection.exec("SELECT * FROM Games WHERE id='#{game_id}'")
    current_game = game[0].to_h
    puts current_game
    current_game["units"] = get_units(game_id)
    puts current_game["units"]
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
    puts "getting players"
    players = @db_connection.exec("SELECT * FROM ActiveGames WHERE game_id='#{game_id}'")
    puts players[0]
    all_players = players.to_a
  end

  def get_types()
    types = @db_connection.exec("SELECT * FROM Types")
    types = types.to_a
  end

  def create_new_game(player_id)
    game = @db_connection.exec("INSERT INTO Games (state, created) VALUES ('BUILD', NOW()) RETURNING *")
    game = game[0]
    @db_connection.exec("INSERT INTO ActiveGames (game_id, player_id) VALUES ('#{game["id"]}', '#{player_id}')")
    unit_info = { game_id: game["id"], player_id: player_id, armor: 5, x: 100, y: 100,
                  heading: -30, energy: 0, type: "T-Fighter", team: 1}
    create_new_unit(unit_info)
    game
  end

  def create_new_unit(unit_info)
    insert_statement = "INSERT INTO Units (game_id, player_id, armor, x, y, heading, energy, type, team) "
    insert_statement += "VALUES (#{unit_info[:game_id]}, #{unit_info[:player_id]}, #{unit_info[:armor]}, #{unit_info[:x]}, #{unit_info[:y]}, #{unit_info[:heading]}, #{unit_info[:energy]}, '#{unit_info[:type]}', #{unit_info[:team]}) "
    insert_statement += "RETURNING *"
    new_unit = @db_connection.exec(insert_statement)
    new_unit = new_unit[0]
  end

  def end_turn(game_id, move_requests)
    
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
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Games(id SERIAL, state VARCHAR(20), created TIMESTAMP)")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Players(id SERIAL, username VARCHAR(50))")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS ActiveGames(game_id INTEGER, player_id INTEGER)")
    @db_connection.exec("CREATE TABLE IF NOT EXISTS Units(id SERIAL, game_id INTEGER, player_id INTEGER, armor FLOAT, x FLOAT, y FLOAT, heading FLOAT, energy FLOAT, type VARCHAR(30), team INTEGER)")
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
