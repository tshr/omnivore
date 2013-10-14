require 'spec_helper'
require 'shared_examples'

describe "GET /request" do
  context "requesting a valid URL" do

    let(:url) {'http://www.example.com/feed.rss'}

    context "and the request isn't cached" do
      before(:each) do
        REDIS.stub(:hgetall).with(url).and_return({})
        RestClient.stub(:get).with(url).and_return("successful response")
        REDIS.stub(:hmset)
      end

      it "stores the url and response in the database, with the 'count' set to
          1, and 'created' and 'updated' set to the current time" do

        REDIS.should_receive(:hmset).with(url,
                                                       "response", "successful response",
                                                       "count", 1,
                                                       "created", Time.now.to_i,
                                                       "updated", Time.now.to_i)
        get '/request?url=' + url
      end

      it_should_behave_like "a successful request", '/request?url=http://www.example.com/feed.rss', "successful response", "xml"
    end

    context "and the request is cached" do

      before(:each) do
        Timecop.freeze(Time.now)
      end

      let(:time_to_live_ago) {Time.now.to_i - TIME_TO_LIVE}
      let(:older_than_time_to_live_ago) {time_to_live_ago - 1}
      let(:younger_than_time_to_live_ago) {time_to_live_ago + 1}

      context "and it is expired" do

        before(:each) do
          REDIS.stub(:hgetall).with(url).and_return(
            { "response" => "cached response",
              "count" => "1",
              "updated" => older_than_time_to_live_ago.to_s
            }
          )

          RestClient.stub(:get).with(url).and_return("successful response")
          REDIS.stub(:multi).and_yield
          REDIS.stub(:hincrby)
          REDIS.stub(:hmset)
        end

        it "resets the response hash with the refreshed response, increments the
            count by one and sets 'updated' to the current time" do
          REDIS.should_receive(:hmset).with(url, "response",
                                                 "successful response",
                                                 "updated",
                                                 Time.now.to_i)
          REDIS.should_receive(:hincrby).with(url, "count", 1)
          get '/request?url=' + url
        end

        it_should_behave_like "a successful request", '/request?url=http://www.example.com/feed.rss', "successful response", "xml"
      end

      context "and it isn't expired" do
        before(:each) do
          REDIS.stub(:hgetall).with(url).and_return(
            { "response" => "cached response",
              "count" => "1",
              "updated" => younger_than_time_to_live_ago.to_s
            }
          )

          REDIS.stub(:hincrby).with(url, "count", 1)
        end

        it "increments the request's count by 1" do
          REDIS.should_receive(:hincrby).with(url, "count", 1)
          get '/request?url=' + url
        end

        it_should_behave_like "a successful request", '/request?url=http://www.example.com/feed.rss', "cached response", "xml"
      end
    end
  end

  context "requesting an invalid URL" do
    let(:invalid_url) {'foo'}

    it "returns a could not connect error in json" do
      REDIS.stub(:hgetall).with(invalid_url).and_return({})
      RestClient.stub(:get).with(invalid_url).and_raise(SocketError.new)

      get '/request?url=' + invalid_url
      last_response.header["Content-Type"].should include "json"
      last_response.body.should include "Could not connect to source."
    end
  end
end