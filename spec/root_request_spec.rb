require 'spec_helper'
require 'shared_examples'

describe "GET /" do
  it_should_behave_like "a successful request", '/', "Hi. I'm Omnivore, your friendly feed cache server.", "html", true
end