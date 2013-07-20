require 'spec_helper'
require 'shared_examples'

describe "GET /request_data" do
  let(:url) {'http://www.example.com/feed.rss'}

  context "The request is not stored" do

    before(:each) do
      REDIS.stub(:hgetall).with(url).and_return({})
    end

    it_should_behave_like "a successful request", '/request_data?url=http://www.example.com/feed.rss', "Request data not found.", "json", true
  end

  context "The request is stored" do

    before(:each) do
      Timecop.freeze(Time.now)
    end

    let (:example_request_hash) {
      {
        "response" => "Stored response",
        "count" => "5",
        "updated" => Time.now.to_i.to_s,
        "created" => (Time.now.to_i - 10).to_s
      }
    }

    before(:each) do
      REDIS.stub(:hgetall).with(url).and_return example_request_hash
    end

    context "The include response param is set to 'true'" do
      before(:each) do
        REDIS.stub(:hincrby).with(url, "count", 1)
        Timecop.freeze(Time.now)
      end

      it "increments the request's count by 1" do
        REDIS.should_receive(:hincrby).with(url, "count", 1)
        get "/request_data?url=#{url}&include_response=true"
      end

      it_should_behave_like "a successful request", '/request_data?url=http://www.example.com/feed.rss&include_response=true',
      {"http://www.example.com/feed.rss" => {"response" => "Stored response","count" => "5","updated" => Time.now.to_i.to_s, "created" => (Time.now.to_i - 10).to_s} }.to_json, "json"
    end

    context "The include response param is not set" do
      it_should_behave_like "a successful request", "/request_data?url=http://www.example.com/feed.rss",
      { "http://www.example.com/feed.rss" => {"count" => "5","updated" => Time.now.to_i.to_s, "created" => (Time.now.to_i - 10).to_s} }.to_json, "json"
    end

    context "The include response param is set to a value other than true" do
      it_should_behave_like "a successful request", "/request_data?url=http://www.example.com/feed.rss&include_response=false",
      { "http://www.example.com/feed.rss" => {"count" => "5","updated" => Time.now.to_i.to_s, "created" => (Time.now.to_i - 10).to_s} }.to_json, "json"
    end
  end
end