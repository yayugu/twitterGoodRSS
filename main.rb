# coding: utf-8

require 'json'
require 'net/http'
require 'time'
require 'rss/maker'

require "bundler/setup"
require 'hashie'
require 'sinatra'

# default:20, max:200
tweet_per_page = 100

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def base_url
    default_port = (request.scheme == "http") ? 80 : 443
    port = (request.port == default_port) ? "" : ":#{request.port.to_s}"
    "#{request.scheme}://#{request.host}#{port}"
  end
end

get '/' do
  <<-EOF
<html>
<title>TwitterGoodRSS</title>
<h1>TwitterGoodRSS</h1>
標準よりましなRSSを生成します。さらにlistのRSSを生成することもできます。<br>
ユーザのRSS: #{base_url}/ユーザ名<br>
listのRSS: #{base_url}/ユーザ名/list名<br>
どちらもTwitterのURLの後ろの方をコピペするといいんじゃないでしょうか
</html>
  EOF
end

# list
get '/:name/:slug' do |name, slug|
  res = Net::HTTP.get('api.twitter.com',
                      "/1/lists/statuses.json?slug=#{slug}&owner_screen_name=#{name}&include_entities=true&per_page=#{tweet_per_page}")
  res = JSON.parse(res, object_class: Hashie::Mash)
  rss = RSS::Maker.make('2.0') do |maker|
    maker.channel.title = "#{slug} / #{name} / Twitter"
    maker.channel.description = ' '
    maker.channel.link = "http://twitter.com/list/#{name}/#{slug}"
    maker.items.do_sort = true
    parse_and_make_items(maker, res)
  end
  rss.to_s
end

get '/:name' do |name|
  res = Net::HTTP.get('api.twitter.com',
                      "/1/statuses/user_timeline.json?screen_name=#{name}&include_entities=true&count=#{tweet_per_page}&include_rts=true")
  res = JSON.parse(res, object_class: Hashie::Mash)
  rss = RSS::Maker.make('2.0') do |maker|
    maker.channel.title = "#{name} / Twitter"
    maker.channel.description = ' '
    maker.channel.link = "http://twitter.com/#{name}"
    maker.image.title = "#{name}'s icon"
    maker.image.url = res.first.user.profile_image_url
    maker.items.do_sort = true
    parse_and_make_items(maker, res)
  end
  rss.to_s
end

def parse_and_make_items(maker, res)
  res.each do |tweet|
    text = MarkupTweet(tweet)

    item = maker.items.new_item
    item.title = tweet.user.screen_name
    item.link = "http://twitter.com/#{tweet.user.screen_name}/status/#{tweet['id']}"
    item.description = " <img src='#{tweet.user.profile_image_url}' /> #{text} "
    item.date = Time.parse(tweet.created_at)
  end
end

def MarkupTweet(tweet)
  text = tweet.text
  entities = tweet.entities
  MarkupTweet::markup_media(text, entities)
  MarkupTweet::markup_urls(text, entities)
  MarkupTweet::markup_user_mentions(text, entities)
  MarkupTweet::markup_hashtags(text, entities)
  text
end

module MarkupTweet
  # see https://dev.twitter.com/docs/tweet-entities
  def self.markup_media(text, entities)
    return text unless entities['media']
    entities.media.each do |image|
      text << "<div><a href='#{image.display_url}'><img src='#{image.media_url}' /></a></div>"
    end
    text
  end

  def self.markup_urls(text, entities)
    entities.urls.each do |url|
      new_url = url.expanded_url || url.url
      text.gsub!(url.url, "<a href='#{new_url}'>#{new_url}</a>")
    end
    text
  end

  def self.markup_user_mentions(text, entities)
    entities.user_mentions.each do |mention|
      text.gsub!("@#{mention.screen_name}", "<a href='http://twitter.com/#{mention.screen_name}'>@#{mention.screen_name}</a>")
    end
    text
  end


  def self.markup_hashtags(text, entities)
    entities.hashtags.each do |hashtag|
      text.gsub!(/[\#＃♯]#{Regexp.quote hashtag.text}/, "<a href='http://twitter.com/search?q=%23#{hashtag.text}'>##{hashtag.text}</a>")
    end
    text
  end
end



