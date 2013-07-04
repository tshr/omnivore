require 'spec_helper'
require 'shared_examples'

describe "GET /configs" do
  it_should_behave_like "a successful request", '/configs', { "Cached item time to live" => "#{TIME_TO_LIVE.to_s} seconds" }.to_json, "json"
end