require 'json'
config_file File.join(File.dirname(__FILE__), '.', 'omnivore_config.yml')


configure do
  REDIS = Redis.new
  TIME_TO_LIVE = settings.time_to_live
end


get '/' do
  File.read(File.join('public', 'index.html'))
end


get '/configs' do
  content_type :json
  { "Cached item time to live" => "#{TIME_TO_LIVE.to_s} seconds" }.to_json
end


get '/request' do
  content_type 'text/xml'

  request_url = params[:url]
  request_hash = REDIS.hgetall request_url

  if request_hash.empty?
    response = get_and_store_request(request_url, REDIS, true)
  else
    request_hash.extend(Cached)
    if request_hash.expired?
      response = get_and_store_request(request_url, REDIS)
    else
      REDIS.hincrby(request_url, "count", 1)
      request_hash["request"]
    end
  end
end


get '/request_data' do
  content_type :json

  request_url = params[:url]
  include_response = (params[:include_response] == "true")

  get_request_data(request_url, include_response).to_json
end


get '/all_requests' do
  content_type :json
  REDIS.keys.map { |key| get_request_data key }.to_json
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

  def get_and_store_request(request_url, redis_client, create = false)
    begin
      response = RestClient.get request_url
    rescue
      content_type :json
      return {error: "Could not connect to source."}.to_json
    end

    # Updated time value stored in Unix epoch seconds
    if create
      now = Time.now.to_i
      redis_client.hmset(request_url, "request", response, "count", 1, "created", now, "updated", now)
    else
      redis_client.multi do
        redis_client.hmset(request_url, "request", response, "updated", Time.now.to_i)
        redis_client.hincrby(request_url, "count", 1)
      end
    end
    response
  end

  def get_request_data (request_url, include_request = false)
    request_hash = REDIS.hgetall request_url

    if request_hash.empty?
      {request_url => {error: "Request data not found."}}.to_json
    else
      # If request is included, count is incremented
      include_request ? REDIS.hincrby(request_url, "count", 1) : request_hash.delete("request")
      response_hash = { request_url => request_hash }
      response_hash
    end
  end
end