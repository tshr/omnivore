require 'spec_helper'

describe "Omnivore" do

  it "should respond to GET" do
    get '/'
    last_response.should be_ok
  end

  it "should return the welcome page at root" do
    get '/'
    last_response.body.should include "Hi. I'm omnivore, your friendly feed cache server."
  end

  
end