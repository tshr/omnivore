require 'spec_helper'
require 'shared_examples'

describe "GET /feed_data" do
  let(:feed_url) {'http://www.example.com/feed.rss'}

  context "The feed is not stored" do

    before(:each) do
      Redis.any_instance.stub(:hgetall).with(feed_url).and_return({})
    end

    it_should_behave_like "a successful request", '/feed_data?url=http://www.example.com/feed.rss', "Feed not found.", "json", true
  end

  context "The feed is stored" do

    before(:each) do
      Timecop.freeze(Time.now)
    end

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