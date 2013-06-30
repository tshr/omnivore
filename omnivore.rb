#!/usr/bin/env ruby -I ../lib -I lib

require 'sinatra'
require 'redis'
require 'rest-client'
require 'json'
require 'debugger'

redis = Redis.new

TIME_TO_LIVE = 60 #in seconds

module Cached
  def expired?
    if self["updated"]
      (self["updated"].to_i + TIME_TO_LIVE) < Time.now.to_i
    else
      false
    end
  end
end

helpers do
  def get_and_store_feed(request_url, count, redis_client)
    response = RestClient.get request_url
    # Updated time value stored in Unix epoch seconds
    redis_client.hmset(request_url, "feed", response, "count", count, "updated", Time.now.to_i)
    response
  end
end

get '/' do
  File.read(File.join('public', 'index.html'))
end

get '/feed' do
  content_type 'text/xml'
  request_url = params[:url]
  feed_hash = redis.hgetall request_url

  if feed_hash.empty?
    response = get_and_store_feed(request_url, 1, redis)
  else
    feed_hash.extend(Cached)
    if feed_hash.expired?
      response = get_and_store_feed(request_url, feed_hash["count"].to_i + 1, redis)
    else
      redis.hincrby(request_url, "count", 1)
      feed_hash["feed"]
    end
  end
end

get '/feed_data' do
  content_type :json

  request_url = params[:url]
  include_feed = (params[:include_feed] == "true")
  feed_hash = redis.hgetall request_url

  if feed_hash.empty?
    {error: "Feed not found."}.to_json
  else
    # If feed is included in data request, count is incremented, otherwise it isn't
    include_feed ? redis.hincrby(request_url, "count", 1) : feed_hash.delete("feed")
    response_hash = { request_url => feed_hash }
    response_hash.to_json
  end
end