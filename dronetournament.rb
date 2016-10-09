require 'pg'
require 'date'
require 'sinatra/activerecord'

class DroneTournament

  def initialize()
      @radian_modifier = Math::PI/180.0
  end

  def sign_in(username, password)
    player = Player.where(username: username, password: password)
    if player.nil?
      player = Player.create(username: username, password: password)
    end

    { "action" => "Sign In", "player_id" => player.id}
  end

  def list_games(player_id)
    games = ActiveGame.where(player_id: player_id)
    if games.nil?
      create_new_game(player_id)
      games = games = ActiveGame.where(player_id: player_id)
    end

    game_list = []

    games.each do |game|
      opponent = games.where("game_id = ? and player_id != ?", game_id, player_id)
      if opponent.nil?
        game["opponent"] = ""
      else
        game["opponent"] = opponent.player_id
      end
      game_list.push(game.to_a)
    end

    {"action" => "List Games", "games" => game_list}
  end

  def get_game(game_id)
    game = Game.find(game_id)
    current_game = game.to_h
    current_game["units"] = get_units(game_id)
    current_game["players"] = get_players(game_id)
    current_game["types"] = get_types()
    current_game["particles"] = get_particles(game_id)
    current_game["action"] = "Load Game"
    current_game
  end

  def get_units(game_id)
    units = Units.where(game_id: game_id)
    units.to_a
  end

  def get_unit(unit_id)
    unit = Unit.find(unit_id)
    unit.to_h
  end

  def get_players(game_id)
    players = ActiveGame.where(game_id: game_id)
    players.to_a
  end

  def get_player(player_id, game_id)
    player = ActiveGame.where(game_id: game_id, player_id: player_id)
  end

  def get_other_players(player_id, game_id)
    other_players = ActiveGame.where("game_id = ? and player_id != ?", game_id, player_id)
    other_players.to_a
  end

  def get_types()
    unit_types = UnitType.all()
    unit_types = unit_types.to_a
  end

  def get_particles(game_id)
    particles = Particle.where(game_id: game_id)
    particles.to_a
  end

  def create_new_game(player_id)
    game = Game.create(state: 'build', turn: 1, max_turns: 30)
    player_one = ActiveGame.create(game_id: game.id, player_number: 1, player_id: player_id, player_state: plan, turn: 1)
    player_two = ActiveGame.create(game_id: game.id, player_number: 2, player_id: 0, player_state: 'empty', turn: 1)

    # TODO get these hashes matching new unit table schema
    unit_one_info = { game_id: game.id, player_id: player_id, armor: 5, x: 100, y: 100,
                  heading: -30, energy: 0, type: "T-Fighter", team: 1, control_x: 100, control_y: 100, control_heading: -30}
    unit_two_info = { game_id: game.id, player_id: 0, armor: 2, x: 300, y: 250,
                  heading: 30, energy: 0, type: "Eye-Fighter", team: 2, control_x: 100, control_y: 100, control_heading: -30}
    turret_info = { game_id: game.id, player_id: player_id, armor: 2, x: 100, y:275,
                  heading: 0, energy: 0, type: "Single Turret", team: 1, control_x: 100, control_y: 100, control_heading: -30}

    Unit.create(unit_one_info)
    Unit.create(turret_info)
    Unit.create(unit_two_info)
    unit_two_info[:y] = 325
    unit_two_info[:control_y] = 325
    Unit.create(unit_two_info)
    game
  end

  def join_game(player_id)
    empty_games = ActiveGame.where(player_state: 'empty')
    if empty_games.nil?
      list_games(player_id)
    else
      game_id = 0
      empty_games.each do |game|
        other_player = ActiveGame.where("game_id = ? and player_state != ?", game.id, 'empty')
        if (other_player.first.player_id == player_id)
          next
        else
          new_player = game.update(player_id: player_id, player_state: 'plan')
          Unit.where(game_id: game.id, player_id: 0).update(player_id: player_id)
          break
        end
      end
      get_game(game_id)
    end
  end

  def end_turn(game_id, move_requests)
    player_id = move_requests["player_id"]
    current_player = get_player(player_id, game_id)
    other_players = get_other_players(player_id, game_id)

    game = get_game(game_id)

    action = "Turn Ended"
    other_players.each do |other_player|
      if other_player["turn"].to_i < current_player["turn"].to_i ||
          (other_player["turn"].to_i == current_player["turn"].to_i && other_player["player_state"] == 'finished')
        action = "Turn Stop"
      end
    end

    if game["turn"].to_i < current_player["turn"].to_i
      action = "Turn Stop"
    end

    if action == "Turn Ended"
      new_turn = current_player["turn"].to_i + 1
      set_player_state(game_id, player_id, 'finished', new_turn)
      move_requests["moves"].each do |move|
        @db_connection.exec("UPDATE Units SET control_x=#{move["control-x"]}, control_y=#{move["control-y"]}, control_heading=#{move["control-heading"]} WHERE player_id=#{player_id} AND id=#{move["unit_id"]}");
      end
    end

    units = get_units(game_id)
    {action: action, units: units}
  end

  def next_turn(game_id, player_id)
    current_player = get_player(player_id, game_id)
    other_players = get_other_players(player_id, game_id)
    game = get_game(game_id)
    action = "Ready"
    first_action = 0

    if current_player["player_state"] != 'finished'
      action = "Waiting"
    else
      other_players.each do |other_player|
        if DateTime.parse(other_player["state_updated"]).to_time.to_i < first_action || first_action == 0
          first_action = DateTime.parse(other_player["state_updated"]).to_time.to_i
        end

        if current_player["turn"].to_i > other_player["turn"].to_i
          action = "Waiting"
        end
      end
    end

    if action == "Ready"
      units = get_units(game_id)
      set_player_state(game_id, player_id, "updated", current_player["turn"])
    end

    { action: action, units: units, player_state: current_player["player_state"] }
  end

  def update_unit_positions(game_id)
    units = get_units(game_id)
    units.each do |unit|
      control_defaults = get_new_control_defaults(unit)
      Unit.find(unit[:id]).update(x: unit.control_x, y: unit.control_y, heading: unit.control_heading, control_x: control_defaults[:x], control_y: control_defaults[:y], control_heading: control_defaults[:heading])
    end
  end

  def get_new_control_defaults(unit)
    # TODO get unit type through active record
    unit_type = get_type(unit["type"])
    new_x = unit["control_x"].to_f + (type["speed"].to_f * Math.cos(unit["control_heading"].to_f * @radian_modifier))
    new_y = unit["control_y"].to_f + (type["speed"].to_f * Math.sin(unit["control_heading"].to_f * @radian_modifier))

    {x: new_x, y: new_y, heading: unit["heading"].to_f}
  end

  def get_type(type_name)
    type = @db_connection.exec("SELECT * FROM Types WHERE name='#{type_name}'")
    type = type[0]
  end

  def set_player_state(game_id, player_id, state, next_turn)
    ActiveGame.where(game_id: game_id, player_id: player_id).update(player_state: state, turn: next_turn)
  end

  def check_all_players_ready(game_id, player_id)
    current_player = get_player(player_id, game_id)
    other_players = get_other_players(player_id, game_id)

    action = "Update Ready"
    other_players.each do |other_player|
      if other_player["turn"].to_i < current_player["turn"].to_i ||
        (other_player["turn"].to_i == current_player["turn"].to_i && other_player["player_state"] == "finished")
        action = "Update Waiting"
      end
    end

    if action == "Update Ready"
      game = get_game(game_id)
      if game["turn"].to_i < current_player["turn"].to_i
        next_turn = game["turn"].to_i + 1
        Game.find(game_id).update(turn: next_turn)
        run_game_loop(game_id, 30)
        update_unit_positions(game_id)
      end

      set_player_state(game_id, player_id, 'plan', current_player["turn"])
    end
    units = get_units(game_id)
    {action: action, units: units}
  end

  def load_types()
    t_fighter = UnitType.new(name: "T-Fighter", speed: 120, turn: 4, armor: 5, full_energy: 100, charge_energy: 5, image_name: "t_fighter.png")
    t_fighter.save

    eye_fighter = UnitType.new(name: "Eye-Fighter", speed: 90, turn: 3, armor: 2, full_energy: 100, charge_energy: 4, image_name: "eye_fighter.png")
    eye_fighter.save

    single_turret = UnitType.new(name: "Single Turret", speed: 0, turn: 2, armor: 3, full_energy: 100, charge_energy: 10, image_name: "single_turret.png")
    single_turret.save
  end


  def run_game_loop(game_id, steps)
    units = get_units(game_id)
    particles = get_particles(game_id)

    particles.each do |particle|
      if particle["remove"].to_i == 1
        Particle.find(particle["id"]).destroy
      end
    end

    units.each do |unit|
      unit["move_points"] = create_move_points(unit["id"], steps)
    end

    steps.to_i.times do |step_count|

      units.each do |unit|
        if (unit["armor"].to_i > 0)
          type = get_type(unit["type"])
          point = unit["move_points"].shift
          unit["x"] = point[:x].to_f
          unit["y"] = point[:y].to_f
          unit["heading"] = point[:heading].to_f
          unit["energy"] = [unit["energy"].to_f + type["charge_energy"].to_f, type["full_energy"].to_f].min
          if (unit["energy"].to_f >= type["full_energy"].to_f)

            Particle.create(game_id: game_id, team: unit["team"], x: unit["x"].to_f, y: unit["y"].to_f, heading: unit["heading"].to_f, speed: 20, power: 1, lifetime: 30, remove: 0)

            unit["energy"] = 0
            Unit.find(unit["id"]).update(energy: 0)
          else
            Unit.find(unit["id"]).update(energy: unit["energy"])
          end

        end
      end

      particles = get_particles(game_id)
      particles.each do |particle|
        if (particle["remove"] != 1)
          start_x = particle["x"].to_f
          start_y = particle["y"].to_f

          particle["x"] = start_x + (particle["speed"].to_f * Math.cos(particle["heading"].to_f * @radian_modifier))
          particle["y"] = start_y + (particle["speed"].to_f * Math.sin(particle["heading"].to_f * @radian_modifier))

          units.each do |unit|
            if ( (unit["armor"].to_i > 0) &&
                 (collided(particle, { x: start_x, y: start_y }, unit)) &&
                 (particle["remove"].to_i != 1) )

              unit["armor"] = unit["armor"].to_f - particle["power"].to_f

              Unit.find(unit["id"]).update(armor: unit["armor"])
              Particle.find(particle["id"]).update(remove: 1)

              particle["remove"] = 1

            end
          end

          if (particle["lifetime"].to_i <= 0)
            Particle.find(particle["id"]).update(remove: 1)
            particle["remove"] = 1
          else
            particle["lifetime"] = particle["lifetime"].to_i - 1
            Particle.find(particle["id"]).update(lifetime: particle["lifetime"], x: particle["x"], y: particle["y"])
          end

        end
      end

    end
  end

  def get_unit_move_points(game_id, player_id, steps, move_requests)
    move_requests["moves"].each do |move|
      @db_connection.exec("UPDATE Units SET control_x=#{move["control-x"]}, control_y=#{move["control-y"]}, control_heading=#{move["control-heading"]} WHERE player_id=#{player_id} AND id=#{move["unit_id"]}");
    end

    units = get_units(game_id)
    move_points = {}
    units.each do |unit|
      if unit["player_id"] == player_id
        move_points[unit["id"]] = create_move_points(unit["id"], steps.to_i)
        @db_connection.exec("UPDATE Units SET control_x=#{move_points[unit["id"]][-1][:x]}, control_y=#{move_points[unit["id"]][-1][:y]}, control_heading=#{move_points[unit["id"]][-1][:heading]} WHERE player_id=#{player_id} AND id=#{unit["id"]}");
      end
    end
    {action: "Server Move Points", move_points: move_points}
  end

  def create_move_points(unit_id, steps)
    unit = get_unit(unit_id)

    type = get_type(unit["type"])
    max_turn = type["turn"].to_f
    distance = type["speed"].to_f/steps.to_f
    move_points = []
    current_point = {x: unit["x"].to_f, y: unit["y"].to_f, heading: unit["heading"].to_f}

    ydiff = unit["control_y"].to_f - unit["y"].to_f
    xdiff = unit["control_x"].to_f - unit["x"].to_f

    goal_heading = Math.atan2(ydiff, xdiff) * (180.0/Math::PI)
    next_heading = 0

    steps.to_i.times do |i|
      start_heading = current_point[:heading].to_f

      if (start_heading < 0)
        start_heading = (start_heading.remainder(360.0)) + 360
      else
        start_heading = start_heading.remainder(360.0)
      end

      if (goal_heading < 0)
        goal_heading = (goal_heading.remainder(360.0)) + 360
      else
        goal_heading = goal_heading.remainder(360.0)
      end

      if (start_heading > goal_heading)
        if (start_heading - goal_heading < 180)
          next_heading = right_turn(start_heading, goal_heading, max_turn)
        else
          next_heading = start_heading + max_turn
        end
      elsif (start_heading < goal_heading)
        if (goal_heading - start_heading < 180)
          next_heading = left_turn(start_heading, goal_heading, max_turn)
        else
          next_heading = start_heading - max_turn
        end
      else
        next_heading = start_heading
      end

      next_x = current_point[:x] + (distance * Math.cos(next_heading * @radian_modifier))
      next_y = current_point[:y] + (distance * Math.sin(next_heading * @radian_modifier))
      current_point = {x: next_x, y: next_y, heading: (next_heading.remainder(360.0)) }

      goal_heading = Math.atan2(unit["control_y"].to_f - next_y, unit["control_x"].to_f - next_x) * (180.0/Math::PI)
      move_points.push(current_point)
    end

    move_points
  end

  def left_turn(start, goal, max)
    return start + [goal - start, max].min
  end

  def right_turn(start, goal, max)
    return start - [start - goal, max].min
  end

  def collided(particle, particle_start, unit)

    particle_end = { x: particle["x"], y: particle["y"] }
    top_left = { x: unit["x"] - 10, y: unit["y"] - 10 }
    top_right = { x: unit["x"] + 10, y: unit["y"] - 10 }
    bottom_left = { x: unit["x"] - 10, y: unit["y"] + 10 }
    bottom_right = { x: unit["x"] + 10, y: unit["y"] + 10 }

    if (particle["team"] == unit["team"])
      return false
    elsif ( lines_intersect(particle_start, particle_end, top_left, top_right) ||
            lines_intersect(particle_start, particle_end, top_left, bottom_left) ||
            lines_intersect(particle_start, particle_end, top_right, bottom_right) ||
            lines_intersect(particle_start, particle_end, bottom_left, bottom_right) )
       "particle collision with unit: #{unit["id"]}"
      return true
    else
      return false
    end
  end

  def lines_intersect(point_a, point_b, point_c, point_d)
    abc = counterclockwise(point_a, point_b, point_c)
    abd = counterclockwise(point_a, point_b, point_d)
    cda = counterclockwise(point_c, point_d, point_a)
    cdb = counterclockwise(point_c, point_d, point_b)

    return  ( (abc != abd) && (cda != cdb) )
  end

  def counterclockwise(point_one, point_two, point_three)
    return ( (point_three[:y] - point_one[:y]) * (point_two[:x] - point_one[:x]) >
             (point_two[:y] - point_one[:y]) * (point_three[:x] - point_one[:x]) )
  end
end
