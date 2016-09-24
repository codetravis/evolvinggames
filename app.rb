require 'sinatra'
require 'sinatra/json'
require 'sinatra/cross_origin'
require 'thin'
require './dronetournament'
require 'json'

configure do
  enable :cross_origin
end

set :allow_origin, :any
set :allow_methods, [:get, :post, :put, :options, :delete]
set :expose_headers, ['Content-Type']

options '*' do
  response.headers['Allow'] = "GET,POST,PUT,DELETE,OPTIONS"
  response.headers['Access-Control-Allow-Headers'] = "X-Requested-With, X-HTTP-Method-Override, Content-Type, Cache-Control, Accept"
  200
end

get '/' do
  erb :home
end

post '/dronetournament/sign_in/:username' do
  json DroneTournament.new.sign_in(params['username'])
end

get '/dronetournament/games/:player_id' do
  json DroneTournament.new.list_games(params['player_id'])
end

get '/dronetournament/game/:game_id' do
  json DroneTournament.new.get_game(params['game_id'])
end

get '/dronetournament/units/:game_id' do
  json DroneTournament.new.get_units(param['game_id'])
end

post '/dronetournament/unit/:game_id/:player_id/:unit_type' do
  json DroneTournament.new.create_new_unit(params['game_id'], params['player_id'], params['unit_type'])
end

post '/dronetournament/end_turn/:game_id' do
  move_requests = JSON.parse(request.body.read)
  json DroneTournament.new.end_turn(params['game_id'], move_requests["data"])
end

get '/dronetournament/next_turn/:game_id/:player_id' do
  json DroneTournament.new.next_turn(params['game_id'], params['player_id'])
end

get '/dronetournament/update_state/:game_id/:player_id' do
  json DroneTournament.new.check_all_players_ready(params['game_id'], params['player_id'])
end

post '/dronetournament/move_points/:game_id/:player_id/:steps' do
  move_requests = JSON.parse(request.body.read)
  json DroneTournament.new.get_unit_move_points(params['game_id'], params['player_id'], params["steps"], move_requests["data"])
end

post '/dronetournament/setup' do
  json DroneTournament.new.setup_tables()
end

post '/dronetournament/new_game/:player_id' do
  json DroneTournament.new.create_new_game(params["player_id"])
end

post '/dronetournament/join_game/:player_id' do
  json DroneTournament.new.join_game(params["player_id"])
end

delete '/dronetournament/destroy' do
  json DroneTournament.new.drop_tables()
end
