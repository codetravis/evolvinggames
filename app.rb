require 'sinatra'
require 'sinatra/json'
require 'thin'
require './dronetournament'

get '/' do
  response.headers['Access-Control-Allow-Origin'] = "*"
  erb :home
end

post '/dronetournament/sign_in/:username' do
  response.headers['Access-Control-Allow-Origin'] = "*"
  json DroneTournament.new.sign_in(params['username'])
end

get '/dronetournament/games/:player_id' do
  response.headers['Access-Control-Allow-Origin'] = "*"
  json DroneTournament.new.list_games(params['player_id'])
end

get '/dronetournament/game/:game_id' do
  response.headers['Access-Control-Allow-Origin'] = "*"
  json DroneTournament.new.get_game(params['game_id'])
end

get '/dronetournament/units/:game_id' do
  response.headers['Access-Control-Allow-Origin'] = "*"
  json DroneTournament.new.get_units(param['game_id'])
end

post '/dronetournament/unit/:game_id/:player_id/:unit_type' do
  response.headers['Access-Control-Allow-Origin'] = "*"
  json DroneTournament.new.create_new_unit(param['game_id'], param['player_id'], param['unit_type'])
end

post 'dronetournament/end_turn/:game_id' do
  move_requests = JSON.parse(request.body.read)
  json DroneTournament.new.end_turn(param['game_id'], move_requests)
end

post '/dronetournament/setup' do
  json DroneTournament.new.setup_tables()
end

post '/dronetournament/new_game/:player_id' do
  json DroneTournament.new.create_new_game(params["player_id"])
end

delete '/dronetournament/destroy' do
  json DroneTournament.new.drop_tables()
end
