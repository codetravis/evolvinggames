require 'bundler/setup'
require './app'
require 'rack'
require 'rack/cors'

use Rack::Cors do
  allow do
    origins '*'
    resource '*', headers: :any, methods: [
      :head, :options, :get, :post
    ]
  end
end

run Sinatra::Application
