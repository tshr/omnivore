require 'spec_helper'

describe "Omnivore" do

  context "In Cached module" do
    context "the expired? method" do
      let(:test_hash) { {} }
      
      before(:each) do
        test_hash.extend(Cached)
        Timecop.freeze(Time.now)
      end
      
      it "should return false if self does not contain an 'updated' key value" do
        test_hash.expired?.should be_false
      end

      it "should return true if self's updated time plus TIME_TO_LIVE is before the current time" do
        test_hash["updated"] = Time.now.to_i - TIME_TO_LIVE - 1
        test_hash.expired?.should be_true
      end

      it "should return false if self's updated time plus TIME_TO_LIVE is the same as the current time" do
        test_hash["updated"] = Time.now.to_i - TIME_TO_LIVE
        test_hash.expired?.should be_false
      end

      it "should return false if self's updated time plus TIME_TO_LIVE is after the current time" do
        test_hash["updated"] = Time.now.to_i - TIME_TO_LIVE + 1
        test_hash.expired?.should be_false
      end
    end
  end

  it "should return the welcome page at root" do
    get '/'
    last_response.should be_ok
    last_response.body.should include "Hi. I'm Omnivore, your friendly feed cache server."
  end
end