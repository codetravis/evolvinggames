require 'pg'
require 'date'
require 'sinatra/activerecord'
require 'bcrypt'
Dir["./models/*.rb"].each {|file| require file }

class DroneTournament

  def initialize()
      @radian_modifier = Math::PI/180.0
      @version = "0.1"
  end

  def sign_in(username, password)
    player = Player.where(username: username).first
    if player.nil?
      password_salt = BCrypt::Engine.generate_salt
      password_hash = BCrypt::Engine.hash_secret(password, password_salt)
      player = Player.create(username: username, password: password_hash, salt: password_salt)
      { "action" => "Sign In", "player_id" => player.id.to_s }
    elsif (BCrypt::Engine.hash_secret(password, player[:salt]) == player[:password])
      { "action" => "Sign In", "player_id" => player.id.to_s }
    else
      { "action" => "Invalid Sign In", "message" => "Username already taken and password incorrect" }
    end
  end

  def list_games(player_id)
    remove_finished_games(player_id)

    active_games = Player.find(player_id).active_games
    if active_games.empty?
      create_new_game(player_id)
      active_games = Player.find(player_id).active_games
    end

    puts active_games.to_a
    {"action" => "List Games", "games" => active_games.to_a}
  end

  def remove_finished_games(player_id)
    player_games = Player.find(player_id).active_games

    if !player_games.empty?
      player_games.each do |player_game|
        player_units = Unit.where("armor > 0 AND player_id = ? AND game_id = ?", player_id, player_game.game_id)
        enemy_units = Unit.where("armor > 0 AND player_id != ? AND game_id = ?", player_id, player_game.game_id)
        if (player_units.count == 0) || (enemy_units.count == 0)
          game = Game.find(player_game.game_id)

          game.units.each do |unit|
            unit.destroy
          end

          game.active_games.each do |a_game|
            a_game.destroy
          end
        end

      end
    end

  end

  def get_game(game_id)
    game = Game.find(game_id)
    current_game = game.serializable_hash
    current_game["units"] = get_units(game_id)
    current_game["players"] = get_players(game_id)
    current_game["types"] = get_types(game.version)
    current_game["particles"] = get_particles(game_id)
    current_game["action"] = "Load Game"
    current_game
  end

  def get_units(game_id)
    units = Game.find(game_id).units
    units.to_a
  end

  def get_players(game_id)
    players = ActiveGame.where(game_id: game_id)
    players.to_a
  end

  def get_player(player_id, game_id)
    player = ActiveGame.where(game_id: game_id, player_id: player_id).first.serializable_hash
  end

  def get_other_players(player_id, game_id)
    other_players = ActiveGame.where("game_id = ? and player_id != ?", game_id, player_id)
    other_players.to_a
  end

  def get_types(version)
    unit_types = UnitType.where(version: version)
    unit_types = unit_types.to_a
  end

  def get_particles(game_id)
    particles = Particle.where(game_id: game_id, remove: 0)
    particles.to_a
  end

  def create_new_game(player_id)
    game = Game.create(state: 'build', turn: 1, max_turn: 30, version: @version)
    player_one = ActiveGame.create(game_id: game.id, player_number: 1, player_id: player_id, player_state: 'plan', player_turn: 1)
    player_two = ActiveGame.create(game_id: game.id, player_number: 2, player_id: 0, player_state: 'empty', player_turn: 1)

    types = UnitType.all()
    unit_one_info = { game_id: game.id, player_id: player_id, armor: 5, x: 30, y: 30,
                  heading: 90, energy: 0, unit_type_id: types.where(name: "T-Fighter", version: @version).first.id, team: 1, control_x: 30, control_y: 100, control_heading: 90}
    unit_two_info = { game_id: game.id, player_id: player_id, armor: 2, x: 70, y: 30,
                  heading: 90, energy: 0, unit_type_id: types.where(name: "Eye-Fighter", version: @version).first.id, team: 1, control_x: 70, control_y: 100, control_heading: 90}

    Unit.create(unit_one_info)
    Unit.create(unit_two_info)
    unit_one_info.merge!({ x: 400, y: 400, heading: 270, player_id: 0, team: 2,
      control_x: 400, control_y: 300, control_heading: 270 })
    Unit.create(unit_one_info)
    unit_two_info.merge!({ x: 440, y: 400, heading: 270, player_id: 0, team: 2,
      control_x: 440, control_y: 300, control_heading: 270 })
    Unit.create(unit_two_info)
    game
  end

  def join_game(player_id)
    empty_games = ActiveGame.where(player_state: 'empty')
    if empty_games.empty?
      list_games(player_id)
    else
      game_id = 0
      empty_games.each do |activegame|
        other_player = ActiveGame.where("game_id = ? and player_state != 'empty'", activegame.game_id)
        if (other_player.first.player_id == player_id.to_i)
          next
        else
          new_player = activegame.update(player_id: player_id, player_state: 'plan')
          Unit.where(game_id: activegame.game_id, player_id: 0).update(player_id: player_id)
          game_id = activegame.game_id
          break
        end
      end

      if game_id == 0
        list_games(player_id)
      else
        get_game(game_id)
      end
    end
  end

  def end_turn(game_id, move_requests)
    player_id = move_requests["player_id"]
    current_player = get_player(player_id, game_id)
    other_players = get_other_players(player_id, game_id)
    game = Game.find(game_id)

    action = "Turn Ended"
    other_players.each do |other_player|
      if other_player["player_turn"].to_i < current_player["player_turn"].to_i ||
          (other_player["player_turn"].to_i == current_player["player_turn"].to_i &&
           other_player["player_state"] == 'finished')
        action = "Turn Stop"
      end
    end

    if game.turn < current_player["player_turn"].to_i
      action = "Turn Stop"
    end

    if action == "Turn Ended"
      new_turn = current_player["player_turn"].to_i + 1
      move_requests["moves"].each do |move|
        Unit.find(move["unit_id"]).update(control_x: move["control-x"], control_y: move["control-y"], control_heading: move["control-heading"])
      end
      set_player_state(game_id, player_id, 'finished', new_turn)
    end

    { action: action }
  end

  def next_turn(game_id, player_id)
    current_player = get_player(player_id, game_id)
    other_players = get_other_players(player_id, game_id)
    action = "Ready"
    first_action = 0

    if current_player["player_state"] != 'finished'
      action = "Waiting"
    else
      other_players.each do |other_player|
        if other_player["updated_at"].to_i < first_action || first_action == 0
          first_action = other_player["updated_at"].to_i
        end

        if current_player["player_turn"].to_i > other_player["player_turn"].to_i
          action = "Waiting"
        end
      end
    end

    if action == "Ready"
      units = get_units(game_id)
      set_player_state(game_id, player_id, "updated", current_player["player_turn"])
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
    unit_type = unit.unit_type
    new_x = unit.control_x + (unit_type.speed * Math.cos(unit.control_heading * @radian_modifier))
    new_y = unit.control_y + (unit_type.speed * Math.sin(unit.control_heading * @radian_modifier))

    {x: new_x, y: new_y, heading: unit.control_heading}
  end

  def set_player_state(game_id, player_id, state, next_turn)
    ActiveGame.where(game_id: game_id, player_id: player_id).update(player_state: state, player_turn: next_turn)
  end

  def check_all_players_ready(game_id, player_id)
    current_player = get_player(player_id, game_id)
    other_players = get_other_players(player_id, game_id)
    game = Game.find(game_id)

    action = "Update Ready"
    other_players.each do |other_player|
      if (game.state == "updating") ||
         (other_player["player_turn"].to_i < current_player["player_turn"].to_i) ||
         (other_player["player_turn"].to_i == current_player["player_turn"].to_i &&
          other_player["player_state"] == "finished")
        action = "Update Waiting"
      end
    end

    if action == "Update Ready"
      if game.turn < current_player["player_turn"].to_i
        game.update(state: "updating")
        next_turn = game.turn + 1
        run_game_loop(game_id, 30)
        update_unit_positions(game_id)
        game.update(turn: next_turn, state: "ready")
      end

      set_player_state(game_id, player_id, 'plan', current_player["player_turn"])
    end

    { action: action }
  end

  def load_types()
    types = UnitType.where(version: @version)
    if types.count == 0
      t_fighter = UnitType.new(name: "T-Fighter", speed: 100, turn: 4, armor: 6, full_energy: 100, charge_energy: 6, image_name: "t_fighter.png", version: @version)
      t_fighter.save

      eye_fighter = UnitType.new(name: "Eye-Fighter", speed: 120, turn: 3, armor: 2, full_energy: 100, charge_energy: 4, image_name: "eye_fighter.png", version: @version)
      eye_fighter.save

      single_turret = UnitType.new(name: "Single Turret", speed: 0, turn: 2, armor: 3, full_energy: 100, charge_energy: 10, image_name: "single_turret.png", version: @version)
      single_turret.save
    end
  end


  def run_game_loop(game_id, steps)
    units = get_units(game_id)
    particles = get_particles(game_id)
    remove_particles = Particle.where(game_id: game_id, remove: 1)
    remove_particles.each do |particle|
      particle.destroy
    end
    move_points = {}
    units.each do |unit|
      move_points[unit.id] = create_move_points(unit.id, steps)
    end

    steps.to_i.times do |step_count|

      units.each do |unit|
        if (unit.armor > 0)
          type = unit.unit_type
          point = move_points[unit.id].shift
          unit.x = point[:x].to_f
          unit.y = point[:y].to_f
          unit.heading = point[:heading].to_f
          unit.energy = [unit.energy + type.charge_energy, type.full_energy].min
          if (unit.energy >= type.full_energy)

            Particle.create(game_id: game_id, team: unit.team, x: unit.x, y: unit.y, heading: unit.heading, speed: 20, power: 1, lifetime: 30, remove: 0)

            unit.energy = 0
            Unit.find(unit.id).update(energy: 0)
          else
            Unit.find(unit.id).update(energy: unit.energy)
          end
        end
      end

      particles = get_particles(game_id)
      particles.each do |particle|
        if (particle.remove != 1)
          start_x = particle.x
          start_y = particle.y

          particle.x = start_x + (particle.speed * Math.cos(particle.heading * @radian_modifier))
          particle.y = start_y + (particle.speed * Math.sin(particle.heading * @radian_modifier))

          units.each do |unit|
            if ( (unit.armor > 0) &&
                 (collided(particle, { x: start_x, y: start_y }, unit)) &&
                 (particle.remove != 1) )

              unit.armor = unit.armor - particle.power

              Unit.find(unit.id).update(armor: unit.armor)
              Particle.find(particle.id).update(remove: 1)

              particle.remove = 1
              break

            end
          end

          if (particle.lifetime <= 0)
            Particle.find(particle.id).update(remove: 1)
            particle.remove = 1
          else
            particle.lifetime -= 1
            Particle.find(particle.id).update(lifetime: particle.lifetime, x: particle.x, y: particle.y)
          end

        end
      end

    end
  end

  def get_unit_move_points(game_id, player_id, steps, move_requests)
    move_requests["moves"].each do |move|
      Unit.find(move["unit_id"]).update(control_x: move["control-x"], control_y: move["control-y"],
                                        control_heading: move["control-heading"])
    end

    units = get_units(game_id)
    move_points = {}
    units.each do |unit|
      puts unit.player_id
      if unit.player_id == player_id.to_i
        move_points[unit.id] = create_move_points(unit.id, steps.to_i)
        last_point = move_points[unit.id][-1]
        unit.update(control_x: last_point[:x], control_y: last_point[:y], control_heading: last_point[:heading])
      end
    end
    { action: "Server Move Points", move_points: move_points }
  end

  def create_move_points(unit_id, steps)
    unit = Unit.find(unit_id)

    type = unit.unit_type
    max_turn = type.turn
    distance = type.speed/steps.to_f
    move_points = []
    current_point = {x: unit.x, y: unit.y, heading: unit.heading}

    ydiff = unit.control_y - unit.y
    xdiff = unit.control_x - unit.x

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

      goal_heading = Math.atan2(unit.control_y - next_y, unit.control_x - next_x) * (180.0/Math::PI)
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
