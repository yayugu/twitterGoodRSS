# coding: utf-8

require 'json'
require 'net/http'
require 'time'
require 'uri'

require 'dm-sqlite-adapter' unless ENV['DATABASE_URL']

require "bundler/setup"
require 'hashie'
require 'oauth'
require 'sinatra'
require 'haml'

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

  def make_items(res)
    res.map do |tweet|
      text = markup_tweet(tweet)

      item = Hashie::Mash.new
      item.title = tweet.user.screen_name
      item.link = "https://twitter.com/#{tweet.user.screen_name}/status/#{tweet['id']}"
      item.description = " <img src='#{tweet.user.profile_image_url}' width='16px' height='16px' /> #{text} "
      item.pub_date = tweet.created_at
      item.author = tweet.source.gsub(/<\/?[^>]*>/, "")
      item
    end
  end

  def screen_name(access_token)
    access_token.get("http://api.twitter.com/1.1/account/verify_credentials.json").body.json_parse['screen_name']
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
<br>
<br>
<br>
<br>
<a href="http://d.hatena.ne.jp/yayugu/20110818/1313627722">詳しい説明</a>
<a href="https://github.com/yayugu/twitterGoodRSS">GitHub</a>
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

  bookmarklet = URI.encode "javascript:void(function(){location.href = '#{base_url}/#{@id}' + location.pathname;})();"
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
    "https://api.twitter.com/1.1/lists/statuses.json?slug=#{slug}&owner_screen_name=#{name}&include_entities=true&per_page=#{tweet_per_page}",
    Account.get!(id)
  )
  @title = "#{slug} / #{name} / Twitter"
  @link = "http://twitter.com/list/#{name}/#{slug}"
  @items = make_items(res)
  haml :rss
end

# user_timeline
get '/:id/:name' do |id, name|
  content_type 'application/rss+xml', :charset => 'utf-8'

  res = oauth_get_and_json_parse(
    "https://api.twitter.com/1.1/statuses/user_timeline.json?screen_name=#{name}&include_entities=true&count=#{tweet_per_page}&include_rts=true",
    Account.get!(id)
  )
  @title = "#{name} / Twitter"
  @link = "http://twitter.com/#{name}"
  @image_title = "#{name}'s icon"
  @image_url = res.first.user.profile_image_url
  @items = make_items(res)
  haml :rss
end
