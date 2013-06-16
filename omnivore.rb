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

get '/' do
  File.read(File.join('public', 'index.html'))
end

get '/feed' do
  content_type 'text/xml'
  request_url = params[:url]
  feed_hash = redis.hgetall request_url

  if feed_hash.empty?
    response = RestClient.get request_url
    redis.hmset(request_url, "feed", response, "count", 1, "updated", Time.now.to_i) #updated time value stored in Unix epoch seconds
    response
  else
    feed_hash.extend(Cached)
    if feed_hash.expired? 
      response = RestClient.get request_url
      redis.hmset(request_url, "feed", response, "count", feed_hash["count"].to_i + 1, "updated", Time.now.to_i)
      response
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
    include_feed ? redis.hincrby(request_url, "count", 1) : feed_hash.delete("feed")
    response_hash = { request_url => feed_hash }
    response_hash.to_json
  end
end