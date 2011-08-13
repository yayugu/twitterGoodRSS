require 'data_mapper'
require 'dm-postgres-adapter'

class Account
  include DataMapper::Resource

  property :id, String, key: true
  property :access_token, String, required: true
  property :access_secret, String, required: true
  property :screen_name, String, required: true
end
