shared_examples_for "a successful request" do |request, content, content_type, include_test = false|

  it "returns an OK response with the correct content type and the expected response body" do
    get request
    last_response.should be_ok
    last_response.header["Content-Type"].should include content_type
    include_test ? (last_response.body.should include content) : (last_response.body.should eq content)
  end

end