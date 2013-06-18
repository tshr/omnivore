require 'spec_helper'

describe "Omnivore" do

  module Cached
    describe "the expired? instance method" do
      let(:test_hash) { {} }
      
      before(:each) do
        test_hash.extend(Cached)
        Timecop.freeze(Time.now)
      end
      
      it "returns false if self does not contain an 'updated' key value" do
        test_hash.expired?.should be_false
      end

      it "returns true if self's updated time plus TIME_TO_LIVE is before the current time" do
        test_hash["updated"] = Time.now.to_i - TIME_TO_LIVE - 1
        test_hash.expired?.should be_true
      end

      it "returns false if self's updated time plus TIME_TO_LIVE is the same as the current time" do
        test_hash["updated"] = Time.now.to_i - TIME_TO_LIVE
        test_hash.expired?.should be_false
      end

      it "returns false if self's updated time plus TIME_TO_LIVE is after the current time" do
        test_hash["updated"] = Time.now.to_i - TIME_TO_LIVE + 1
        test_hash.expired?.should be_false
      end
    end
  end

  context "GET /" do
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

  context "GET /feed" do
    context "requesting a valid feed URL" do

      let(:valid_feed_url) {'http://www.example.com/feed.rss'}
      
      context "and the feed isn't cached" do
        xit "stores the feed response in the database" do
          # redis = double('redis')
          # get '/feed?url=' + valid_feed_url
          # redis.should_receive(:hgetall).with(valid_feed_url).and_return({})
        end

        xit "sets the feed hash's count to 1" do
        end

        xit "sets updated to the current time" do
        end

        xit "responds OK" do
          last_response.should be_ok
        end
        
        xit "returns the requested feed" do

        end
      end
    end
  end
end