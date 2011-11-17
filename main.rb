# coding: utf-8

require 'json'
require 'net/http'
require 'time'
require 'rss/maker'
require 'uri'

require 'dm-sqlite-adapter' unless ENV['DATABASE_URL']

require "bundler/setup"
require 'hashie'
require 'oauth'
require 'sinatra'

require './model.rb'
require './markup_tweet.rb'

# set ENV[CONSUMER_KEY] and ENV[CONSUMER_SECRET] in this file or another way to use OAuth
require './env.rb' if File.exist?('./env.rb')

# default:20, max:200
tweet_per_page = 100

configure do
  enable :sessions
  DataMapper::Logger.new($stdout, :debug)
  DataMapper.finalize
  DataMapper.setup(:default, ENV['DATABASE_URL'] || 'sqlite3:db.sqlite3')
end

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def base_url
    default_port = (request.scheme == "http") ? 80 : 443
    port = (request.port == default_port) ? "" : ":#{request.port.to_s}"
    "#{request.scheme}://#{request.host}#{port}"
  end

  class String
    def json_parse(*a, &b)
      JSON.parse(self, *a, &b)
    end
  end

  def make_items(maker, res)
    res.each do |tweet|
      text = markup_tweet(tweet)

      item = maker.items.new_item
      item.title = tweet.user.screen_name
      item.link = "http://twitter.com/#{tweet.user.screen_name}/status/#{tweet['id']}"
      item.description = " <img src='#{tweet.user.profile_image_url}' width='16px' height='16px' /> #{text} "
      item.date = Time.parse(tweet.created_at)
    end
  end

  def screen_name(access_token)
    access_token.get("http://api.twitter.com/1/account/verify_credentials.json").body.json_parse['screen_name']
  end

  def oauth_consumer
    OAuth::Consumer.new(
      ENV['CONSUMER_KEY'], 
      ENV['CONSUMER_SECRET'], 
      site: 'http://api.twitter.com'
    )
  end

  def oauth_get_and_json_parse(url, account)
    OAuth::AccessToken.new(oauth_consumer, account.access_token, account.access_secret)
    .get(url)
    .body
    .json_parse(object_class: Hashie::Mash)
  end
end

get '/' do
  <<-EOF
<html>
<title>TwitterGoodRSS</title>
<h1>TwitterGoodRSS</h1>
標準よりましなRSSを生成します。さらに公式ではできないListのRSSの生成もできます。<br>
OAuth認証をするとidが生成されるので、<br>
ユーザのRSS: #{base_url}/id/ユーザ名<br>
listのRSS: #{base_url}/id/ユーザ名/list名<br>
でRSSを取得できます。<br>
どちらもTwitterのURLの後ろの方をコピペするといいんじゃないでしょうか。<br>
ブックマークレットもあります。<br>

<a href="#{base_url}/auth" style="font-size:20pt">登録する</a>
</html>
  EOF
end

get '/auth' do
  callback_url = "#{base_url}/callback"
  request_token = oauth_consumer.get_request_token(:oauth_callback => callback_url)
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url
end

get '/callback' do
  request_token = OAuth::RequestToken.new(oauth_consumer, session[:request_token], session[:request_token_secret])
  begin
    @access_token = request_token.get_access_token(
      {},
      :oauth_token => params[:oauth_token],
      :oauth_verifier => params[:oauth_verifier]
    )
  rescue OAuth::Unauthorized => @exception
    return erb %{oauth failed: <%=h @exception.message %>}
  end
  @screen_name = screen_name(@access_token)

  # 重複しない&RandomなKeyを生成
  begin
    @id = rand(10**20 - 1)
  end while Account.get(@id)

  Account.create(
    id: "%19d" % [@id],
    screen_name: @screen_name,
    access_token: @access_token.token,
    access_secret: @access_token.secret
  )

  bookmarklet = URI.encode "javascript:void(function(){location.href = '#{base_url}/#{@id}' + location.href.match(/[a-zA-Z0-9\_\/]+$/);})();"
  <<-EOF
<html>
<title>TwitterGoodRSS</title>
<h1>TwitterGoodRSS</h1>
あなたのidは<b>#{@id}</b>です<br>
ユーザのRSS: #{base_url}/#{@id}/ユーザ名<br>
listのRSS: #{base_url}/#{@id}/ユーザ名/list名<br>
でRSSを取得できます。<br>
どちらもTwitterのURLの後ろの方をコピペするといいんじゃないでしょうか<br>
一応ブックマークレットもあります↓<br>
<a href="#{bookmarklet}">
TwitterGoodRSS
</a>
</html>
  EOF
end

# list
get '/:id/:name/:slug' do |id, name, slug|
  content_type 'application/rss+xml', :charset => 'utf-8'

  res = oauth_get_and_json_parse(
    "http://api.twitter.com/1/lists/statuses.json?slug=#{slug}&owner_screen_name=#{name}&include_entities=true&per_page=#{tweet_per_page}",
    Account.get!(id)
  )
  RSS::Maker.make('2.0') do |maker|
    maker.channel.title = "#{slug} / #{name} / Twitter"
    maker.channel.description = ' '
    maker.channel.link = "http://twitter.com/list/#{name}/#{slug}"
    maker.items.do_sort = true
    make_items(maker, res)
  end.to_s
end

# user_timeline
get '/:id/:name' do |id, name|
  res = oauth_get_and_json_parse(
    "http://api.twitter.com/1/statuses/user_timeline.json?screen_name=#{name}&include_entities=true&count=#{tweet_per_page}&include_rts=true",
    Account.get!(id)
  )
  RSS::Maker.make('2.0') do |maker|
    maker.channel.title = "#{name} / Twitter"
    maker.channel.description = ' '
    maker.channel.link = "http://twitter.com/#{name}"
    maker.image.title = "#{name}'s icon"
    maker.image.url = res.first.user.profile_image_url
    maker.items.do_sort = true
    make_items(maker, res)
  end.to_s
end
