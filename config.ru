require 'bundler/setup'
require './app'
run Sinatra::Application

use Rack::Cors do
  allow do
    origins '*'
    resource '*', :headers => :any, :methods => [:get, :post, :options]
  end
end
