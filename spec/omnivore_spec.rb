require 'spec_helper'

describe "Omnivore" do
  before(:each) do
    Timecop.freeze(Time.now)
  end

  let(:time_to_live_ago) {Time.now.to_i - TIME_TO_LIVE}
  let(:older_than_time_to_live_ago) {time_to_live_ago - 1}
  let(:younger_than_time_to_live_ago) {time_to_live_ago + 1}

  describe "Cached module" do
    describe "the expired? instance method" do
      let(:test_hash) { {} }
      
      before(:each) do
        test_hash.extend(Cached)
      end
      
      it "returns false if self does not contain an 'updated' key value" do
        test_hash.expired?.should be_false
      end

      it "returns true if self's updated time plus TIME_TO_LIVE is before the current time" do
        test_hash["updated"] = older_than_time_to_live_ago
        test_hash.expired?.should be_true
      end

      it "returns false if self's updated time plus TIME_TO_LIVE is the same as the current time" do
        test_hash["updated"] = time_to_live_ago
        test_hash.expired?.should be_false
      end

      it "returns false if self's updated time plus TIME_TO_LIVE is after the current time" do
        test_hash["updated"] = younger_than_time_to_live_ago
        test_hash.expired?.should be_false
      end
    end
  end

  describe "GET /" do
    before(:each) do
      get '/'
    end

    it "responds OK" do
      last_response.should be_ok
    end

    it "returns the welcome page" do  
      last_response.body.should include "Hi. I'm Omnivore, your friendly feed cache server."
    end
  end

  describe "GET /feed" do
    context "requesting a valid feed URL" do

      let(:valid_feed_url) {'http://www.example.com/feed.rss'}

      context "and the feed isn't cached" do
        before(:each) do
          Redis.any_instance.stub(:hgetall).with(valid_feed_url).and_return({})
          RestClient.stub(:get).with(valid_feed_url).and_return("successful response")
        end

        it "stores the feed url and response in the database, with the 'count' set to
            1, and 'updated' set to the current time" do
          Redis.any_instance.should_receive(:hmset).with(valid_feed_url, "feed",
                                                         "successful response",
                                                         "count", 1, "updated",
                                                         Time.now.to_i)
          get '/feed?url=' + valid_feed_url
        end

        context "returns the feed and an OKresponse" do
          before(:each) do
            Redis.any_instance.stub(:hmset)
            get '/feed?url=' + valid_feed_url
          end

          it "responds OK" do
            last_response.should be_ok
          end

          it "returns the response feed" do
            last_response.body.should == "successful response"
          end

          it "returns a content type of xml" do
            last_response.header["Content-Type"].should include "text/xml"
          end
        end
      end

      context "and the feed is cached" do

        context "and it is expired" do

          let(:returned_feed_count) {"1"}

          before(:each) do
            Redis.any_instance.stub(:hgetall).with(valid_feed_url).and_return(
              { "feed" => "cached feed",
                "count" => returned_feed_count,
                "updated" => older_than_time_to_live_ago.to_s
              }
            )
            RestClient.stub(:get).with(valid_feed_url).and_return("successful response")
            Redis.any_instance.stub(:hmset).with(valid_feed_url, "feed",
                                                    "successful response",
                                                    "count", returned_feed_count.to_i + 1, "updated",
                                                    Time.now.to_i)
          end

          it "resets the feed hash with the refreshed response, increments the
              count by one and sets 'updated' to the current time" do
            Redis.any_instance.should_receive(:hmset).with(valid_feed_url, "feed",
                                                           "successful response",
                                                           "count", returned_feed_count.to_i + 1, "updated",
                                                           Time.now.to_i)
            get '/feed?url=' + valid_feed_url
          end

          it "responds OK" do
            get '/feed?url=' + valid_feed_url
            last_response.should be_ok
          end

          it "returns the response feed" do
            get '/feed?url=' + valid_feed_url
            last_response.body.should == "successful response"
          end

          it "returns a content type of xml" do
            get '/feed?url=' + valid_feed_url
            last_response.header["Content-Type"].should include "text/xml"
          end
        end
        context "and it isn't expired" do
          before(:each) do
            Redis.any_instance.stub(:hgetall).with(valid_feed_url).and_return(
              { "feed" => "cached feed",
                "count" => "1",
                "updated" => younger_than_time_to_live_ago.to_s
              }
            )
          end

          it "increments the feed's count by 1" do
            Redis.any_instance.should_receive(:hincrby).with(valid_feed_url, "count", 1)
            get '/feed?url=' + valid_feed_url
          end

          it "responds OK" do
            Redis.any_instance.stub(:hincrby).with(valid_feed_url, "count", 1)
            get '/feed?url=' + valid_feed_url
            last_response.should be_ok
          end

          it "returns the cached feed" do
            Redis.any_instance.stub(:hincrby).with(valid_feed_url, "count", 1)
            get '/feed?url=' + valid_feed_url
            last_response.body.should == "cached feed"
          end

          it "returns a content type of xml" do
            Redis.any_instance.stub(:hincrby).with(valid_feed_url, "count", 1)
            get '/feed?url=' + valid_feed_url
            last_response.header["Content-Type"].should include "text/xml"
          end
        end
      end
    end
  end

  describe "GET /feed_data" do
    let(:feed_url) {'http://www.example.com/feed.rss'}

    context "The feed is not stored" do

      before(:each) do
        Redis.any_instance.stub(:hgetall).with(feed_url).and_return({})
        get '/feed_data?url=' + feed_url
      end

      it "returns a content type of json" do
        last_response.header["Content-Type"].should include "application/json"
      end

      it "returns a 'Feed not found.' error message" do
        last_response.body.should include "Feed not found."
      end
    end

    context "The feed is stored" do

      let (:example_feed_hash) {
        {
          "feed" => "stored feed",
          "count" => "5",
          "updated" => Time.now.to_i.to_s
        }
      }

      before(:each) do
        Redis.any_instance.stub(:hgetall).with(feed_url).and_return example_feed_hash
      end

      it "returns a content type of json" do
        get '/feed_data?url=' + feed_url
        last_response.header["Content-Type"].should include "application/json"
      end

      context "The include feed param is set to 'true'" do
        before(:each) do
          Redis.any_instance.stub(:hincrby).with(feed_url, "count", 1)
        end

        it "increments the feed's count by 1" do
          Redis.any_instance.should_receive(:hincrby).with(feed_url, "count", 1)
          get "/feed_data?url=#{feed_url}&include_feed=true"
        end

        it "returns a content type of json" do
          get "/feed_data?url=#{feed_url}&include_feed=true"
          last_response.header["Content-Type"].should include "application/json"
        end

        it "returns the feed data" do
          get "/feed_data?url=#{feed_url}&include_feed=true"
          last_response.body.should == { feed_url => example_feed_hash }.to_json
        end
      end

      context "The include feed param is not set" do
      end

      context "The include feed param is set to a value other than true" do

      end
    end
  end
end