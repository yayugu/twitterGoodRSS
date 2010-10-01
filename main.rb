$KCODE = 'u'
require 'erb'
require 'rubygems'
require 'json'
require 'sinatra'
require 'net/http'
require 'time'
require 'rss/maker'
require 'uri'


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


get '/:name' do |name|
  res = Net::HTTP.get('api.twitter.com',
                      "/1/statuses/user_timeline.json?screen_name=#{name}&count=200")
  res = JSON.parse(res)
  rss = RSS::Maker.make('2.0') do |maker|
    maker.channel.about = "#{base_url}/#{name}"
    maker.channel.title = "#{name} / Twitter"
    maker.channel.description = ' '
    maker.channel.link = "http://twitter.com/#{name}"
    maker.image.title = "#{name}'s icon"
    maker.image.url = res[0]['user']['profile_image_url']
    maker.items.do_sort = true
    
    res.each do |tweet|
      # escape and make link
      text = h tweet['text']
      URI.extract(text).each do |uri|
        text.gsub!(uri, '<a href="\0">\0</a>')
      end
      text.gsub!(/(?:#)([A-Za-z0-9_]+)/, '<a href="http://twitter.com/search?q=%23\1">#\1</a>')
      text.gsub!(/@[A-Za-z0-9_]+/, '<a href="http://twitter.com/\0">\0</a>')

      item = maker.items.new_item
      item.title = name
      item.link = "http://twitter.com/#{name}/status/#{tweet['id']}"
      item.description = %Q| <img src="#{tweet['user']['profile_image_url']}"> #{text} |
      item.date = Time.parse(tweet['created_at'])
    end
  end
  rss.to_s
end
