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
  response_hash = REDIS.hgetall request_url

  if response_hash.empty?
    get_and_store_response(request_url, true)
  # Check if expired
  elsif response_hash["updated"].to_i + TIME_TO_LIVE < Time.now.to_i
     get_and_store_response(request_url)
  else
     REDIS.hincrby(request_url, "count", 1)
     response_hash["response"]
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

helpers do

  def get_and_store_response(request_url, create_redis_record = false)
    begin
      response = RestClient.get request_url
    rescue
      content_type :json
      return { error: "Could not connect to source." }.to_json
    end

    # Updated time value stored in Unix epoch seconds
    now = Time.now.to_i

    if create_redis_record
      REDIS.hmset(request_url, "response", response, "count", 1, "created", now, "updated", now)
    else
      REDIS.multi do
        REDIS.hmset(request_url, "response", response, "updated", now)
        REDIS.hincrby(request_url, "count", 1)
      end
    end
    response
  end

  def get_request_data (request_url, include_response = false)
    response_hash = REDIS.hgetall request_url

    if response_hash.empty?
      response = { request_url => { error: "Request data not found." } }
    else
      # If request is included, count is incremented
      if include_response
        REDIS.hincrby(request_url, "count", 1)
        response_hash["count"].next!
      else
        response_hash.delete("response")
      end
      response = { request_url => response_hash }
    end
    response
  end
end
