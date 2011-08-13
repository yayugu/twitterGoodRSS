require 'data_mapper'
require 'dm-postgres-adapter'

class Account
  include DataMapper::Resource

  property :id, Serial
  property :screen_name, String, required: true
  property :access_token, String, key: true
  property :access_secret, String, required: true
end
