require 'spec_helper'

describe "Omnivore" do
  before(:each) do
    Timecop.freeze(Time.now)
  end

  shared_examples_for "a successful request" do |request, content, content_type, include = false|

    before(:each) do
      get request
    end

    it "responds OK" do
      last_response.should be_ok
    end

    it "returns the response feed" do
      include ? (last_response.body.should include content) : (last_response.body.should == content)
    end

    it "returns a content type of xml" do
      last_response.header["Content-Type"].should include content_type
    end
  end

  describe "GET /" do
    it_should_behave_like "a successful request", '/', "Hi. I'm Omnivore, your friendly feed cache server.", "html", true
  end

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

  describe "GET /feed_data" do
    let(:feed_url) {'http://www.example.com/feed.rss'}

    context "The feed is not stored" do

      before(:each) do
        Redis.any_instance.stub(:hgetall).with(feed_url).and_return({})
      end

      it_should_behave_like "a successful request", '/feed_data?url=http://www.example.com/feed.rss', "Feed not found.", "json", true
    end

    context "The feed is stored" do

      let (:example_feed_hash) {
        {
          "feed" => "Stored feed",
          "count" => "5",
          "updated" => Time.now.to_i.to_s
        }
      }

      before(:each) do
        Redis.any_instance.stub(:hgetall).with(feed_url).and_return example_feed_hash
      end

      context "The include feed param is set to 'true'" do
        before(:each) do
          Redis.any_instance.stub(:hincrby).with(feed_url, "count", 1)
        end

        it "increments the feed's count by 1" do
          Redis.any_instance.should_receive(:hincrby).with(feed_url, "count", 1)
          get "/feed_data?url=#{feed_url}&include_feed=true"
        end

        it_should_behave_like "a successful request", '/feed_data?url=http://www.example.com/feed.rss&include_feed=true',
        {"http://www.example.com/feed.rss" => {"feed" => "Stored feed","count" => "5","updated" => Time.now.to_i.to_s}}.to_json, "json"

      end

      context "The include feed param is not set" do
        it_should_behave_like "a successful request", "/feed_data?url=http://www.example.com/feed.rss",
        { "http://www.example.com/feed.rss" => {"count" => "5","updated" => Time.now.to_i.to_s} }.to_json, "json"

      end

      context "The include feed param is set to a value other than true" do
        it_should_behave_like "a successful request", "/feed_data?url=http://www.example.com/feed.rss&include_feed=false",
        { "http://www.example.com/feed.rss" => {"count" => "5","updated" => Time.now.to_i.to_s} }.to_json, "json"

      end
    end
  end
end