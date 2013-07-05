require 'spec_helper'
require 'shared_examples'


describe "GET /all_feed_data" do
  before(:each) do
    REDIS.stub(:keys).and_return(["key1", "key2", "key3"])
    Sinatra::Application.any_instance.stub(:get_feed_data) do |key|
      { key => "stored data" }
    end
  end

  it_should_behave_like "a successful request", '/all_feed_data', [{"key1" => "stored data"}, {"key2" => "stored data"}, {"key3" => "stored data"}].to_json, "json"
end