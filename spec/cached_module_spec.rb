require 'spec_helper'

describe Cached do
  describe "the expired? instance method" do

    let(:test_hash) { {} }
    let(:time_to_live_ago) {Time.now.to_i - TIME_TO_LIVE}
    let(:older_than_time_to_live_ago) {time_to_live_ago - 1}
    let(:younger_than_time_to_live_ago) {time_to_live_ago + 1}

    before(:each) do
      Timecop.freeze(Time.now)
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