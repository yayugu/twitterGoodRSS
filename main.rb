require 'erb'
require 'rubygems'
require 'json'
require 'haml'
require 'sinatra'


helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def base_url
    default_port = (request.scheme == "http") ? 80 : 443
    port = (request.port == default_port) ? "" : ":#{request.port.to_s}"
    "#{request.scheme}://#{request.host}#{port}"
  end
end

configure do
  enable :sessions
  set :public, File.dirname(__FILE__) + '/public'
  set :views, File.dirname(__FILE__) + '/views'
end


get '/' do
  #haml :index
  erb "hello world"
end
