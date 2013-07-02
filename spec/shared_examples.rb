shared_examples_for "a successful request" do |request, content, content_type, include = false|

  before(:each) do
    get request
  end

  it "responds OK" do
    last_response.should be_ok
  end

  it "returns the expected response feed" do
    include ? (last_response.body.should include content) : (last_response.body.should eq content)
  end

  it "returns the expected content type" do
    last_response.header["Content-Type"].should include content_type
  end
end