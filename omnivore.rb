require 'json'
config_file File.join(File.dirname(__FILE__), '.', 'omnivore_config.yml')

configure do
  REDIS = Redis.new
  TIME_TO_LIVE = settings.time_to_live
end

get '/' do
  File.read(File.join('public', 'index.html'))
end


get '/feed' do
  content_type 'text/xml'

  request_url = params[:url]
  feed_hash = REDIS.hgetall request_url

  if feed_hash.empty?
    response = get_and_store_feed(request_url, REDIS, true)
  else
    feed_hash.extend(Cached)
    if feed_hash.expired?
      response = get_and_store_feed(request_url, REDIS)
    else
      REDIS.hincrby(request_url, "count", 1)
      feed_hash["feed"]
    end
  end
end


get '/feed_data' do
  content_type :json

  request_url = params[:url]
  include_feed = (params[:include_feed] == "true")
  feed_hash = REDIS.hgetall request_url

  if feed_hash.empty?
    {error: "Feed not found."}.to_json
  else
    # If feed is included in data request, count is incremented, otherwise it isn't
    include_feed ? REDIS.hincrby(request_url, "count", 1) : feed_hash.delete("feed")
    response_hash = { request_url => feed_hash }
    response_hash.to_json
  end
end


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
  def get_and_store_feed(request_url, redis_client, create = false)
    begin
      response = RestClient.get request_url
    rescue
      content_type :json
      return {error: "Could not connect to feed source."}.to_json
    end

    # Updated time value stored in Unix epoch seconds
    if create
      redis_client.hmset(request_url, "feed", response, "count", 1, "created", Time.now.to_i, "updated", Time.now.to_i)
    else
      redis_client.multi do
        redis_client.hmset(request_url, "feed", response, "updated", Time.now.to_i)
        redis_client.hincrby(request_url, "count", 1)
      end
    end
    response
  end
end