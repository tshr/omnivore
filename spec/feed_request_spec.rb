require 'spec_helper'
require 'shared_examples'

describe "GET /feed" do
  context "requesting a valid feed URL" do

    let(:feed_url) {'http://www.example.com/feed.rss'}

    context "and the feed isn't cached" do
      before(:each) do
        Redis.any_instance.stub(:hgetall).with(feed_url).and_return({})
        RestClient.stub(:get).with(feed_url).and_return("successful response")
        Redis.any_instance.stub(:hmset)
      end

      it "stores the feed url and response in the database, with the 'count' set to
          1, and 'updated' set to the current time" do

        Redis.any_instance.should_receive(:hmset).with(feed_url, "feed",
                                                       "successful response",
                                                       "count", 1, "updated",
                                                       Time.now.to_i)
        get '/feed?url=' + feed_url
      end

      it_should_behave_like "a successful request", '/feed?url=http://www.example.com/feed.rss', "successful response", "xml"
    end

    context "and the feed is cached" do
  
      before(:each) do
        Timecop.freeze(Time.now)
      end

      let(:time_to_live_ago) {Time.now.to_i - TIME_TO_LIVE}
      let(:older_than_time_to_live_ago) {time_to_live_ago - 1}
      let(:younger_than_time_to_live_ago) {time_to_live_ago + 1}

      context "and it is expired" do

        let(:returned_feed_count) {"1"}

        before(:each) do
          Redis.any_instance.stub(:hgetall).with(feed_url).and_return(
            { "feed" => "cached feed",
              "count" => returned_feed_count,
              "updated" => older_than_time_to_live_ago.to_s
            }
          )

          RestClient.stub(:get).with(feed_url).and_return("successful response")
          Redis.any_instance.stub(:hmset)
        end

        it "resets the feed hash with the refreshed response, increments the
            count by one and sets 'updated' to the current time" do
          Redis.any_instance.should_receive(:hmset).with(feed_url, "feed",
                                                         "successful response",
                                                         "count", returned_feed_count.to_i + 1, "updated",
                                                         Time.now.to_i)
          get '/feed?url=' + feed_url
        end

        it_should_behave_like "a successful request", '/feed?url=http://www.example.com/feed.rss', "successful response", "xml"
      end

      context "and it isn't expired" do
        before(:each) do
          Redis.any_instance.stub(:hgetall).with(feed_url).and_return(
            { "feed" => "cached feed",
              "count" => "1",
              "updated" => younger_than_time_to_live_ago.to_s
            }
          )

          Redis.any_instance.stub(:hincrby).with(feed_url, "count", 1)
        end

        it "increments the feed's count by 1" do
          Redis.any_instance.should_receive(:hincrby).with(feed_url, "count", 1)
          get '/feed?url=' + feed_url
        end

        it_should_behave_like "a successful request", '/feed?url=http://www.example.com/feed.rss', "cached feed", "xml"
      end
    end
  end
end