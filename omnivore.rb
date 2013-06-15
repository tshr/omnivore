#!/usr/bin/env ruby -I ../lib -I lib

require 'sinatra'
require 'redis'
require 'rest-client'
require 'json'

redis = Redis.new

get '/' do
  erb :index
end

get '/feed' do
  content_type 'text/xml'

  request_url = params[:url]
  feed_hash = redis.hgetall request_url

  if feed_hash.empty?
    response = RestClient.get request_url
    redis.hmset(request_url, "feed", response, "count", 1)
    response
  else
    redis.hincrby(request_url, "count", 1)
    feed_hash["feed"]
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
    feed_hash.delete("feed") unless include_feed
    response_hash = { request_url => feed_hash }
    response_hash.to_json
  end
end