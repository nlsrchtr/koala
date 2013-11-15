require 'spec_helper'

describe "Koala::Facebook::API" do
  before(:each) do
    @service = Koala::Facebook::API.new
  end

  it "doesn't include an access token if none was given" do
    Koala.should_receive(:make_request).with(
      anything,
      hash_not_including('access_token' => 1),
      anything,
      anything
    ).and_return(Koala::HTTPService::Response.new(200, "", ""))

    @service.api('anything')
  end

  it "includes an access token if given" do
    token = 'adfadf'
    service = Koala::Facebook::API.new token

    Koala.should_receive(:make_request).with(
      anything,
      hash_including('access_token' => token),
      anything,
      anything
    ).and_return(Koala::HTTPService::Response.new(200, "", ""))

    service.api('anything')
  end

  it "has an attr_reader for access token" do
    token = 'adfadf'
    service = Koala::Facebook::API.new token
    service.access_token.should == token
  end

  it "gets the attribute of a Koala::HTTPService::Response given by the http_component parameter" do
    http_component = :method_name

    response = mock('Mock KoalaResponse', :body => '', :status => 200)
    result = stub("result")
    response.stub(http_component).and_return(result)
    Koala.stub(:make_request).and_return(response)

    @service.api('anything', {}, 'get', :http_component => http_component).should == result
  end

  it "returns the entire response if http_component => :response" do
    http_component = :response
    response = mock('Mock KoalaResponse', :body => '', :status => 200)
    Koala.stub(:make_request).and_return(response)
    @service.api('anything', {}, 'get', :http_component => http_component).should == response
  end

  it "turns arrays of non-enumerables into comma-separated arguments" do
    args = [12345, {:foo => [1, 2, "3", :four]}]
    expected = ["/12345", {:foo => "1,2,3,four"}, "get", {}]
    response = mock('Mock KoalaResponse', :body => '', :status => 200)
    Koala.should_receive(:make_request).with(*expected).and_return(response)
    @service.api(*args)
  end

  it "doesn't turn arrays containing enumerables into comma-separated strings" do
    params = {:foo => [1, 2, ["3"], :four]}
    args = [12345, params]
    # we leave this as is -- the HTTP layer can either handle it appropriately
    # (if appropriate behavior is defined)
    # or raise an exception
    expected = ["/12345", params, "get", {}]
    response = mock('Mock KoalaResponse', :body => '', :status => 200)
    Koala.should_receive(:make_request).with(*expected).and_return(response)
    @service.api(*args)
  end

  it "returns the body of the request as JSON if no http_component is given" do
    response = stub('response', :body => 'body', :status => 200)
    Koala.stub(:make_request).and_return(response)

    json_body = mock('JSON body')
    MultiJson.stub(:load).and_return([json_body])

    @service.api('anything').should == json_body
  end

  it "executes an error checking block if provided" do
    response = Koala::HTTPService::Response.new(200, '{}', {})
    Koala.stub(:make_request).and_return(response)

    yield_test = mock('Yield Tester')
    yield_test.should_receive(:pass)

    @service.api('anything', {}, "get") do |arg|
      yield_test.pass
      arg.should == response
    end
  end

  it "raises an API error if the HTTP response code is greater than or equal to 500" do
    Koala.stub(:make_request).and_return(Koala::HTTPService::Response.new(500, 'response body', {}))

    lambda { @service.api('anything') }.should raise_exception(Koala::Facebook::APIError)
  end

  it "handles rogue true/false as responses" do
    Koala.should_receive(:make_request).and_return(Koala::HTTPService::Response.new(200, 'true', {}))
    @service.api('anything').should be_true

    Koala.should_receive(:make_request).and_return(Koala::HTTPService::Response.new(200, 'false', {}))
    @service.api('anything').should be_false
  end

  describe "with regard to leading slashes" do
    it "adds a leading / to the path if not present" do
      path = "anything"
      Koala.should_receive(:make_request).with("/#{path}", anything, anything, anything).and_return(Koala::HTTPService::Response.new(200, 'true', {}))
      @service.api(path)
    end

    it "doesn't change the path if a leading / is present" do
      path = "/anything"
      Koala.should_receive(:make_request).with(path, anything, anything, anything).and_return(Koala::HTTPService::Response.new(200, 'true', {}))
      @service.api(path)
    end
  end

  describe "with an access token" do
    before(:each) do
      @api = Koala::Facebook::API.new(@token)
    end

    it_should_behave_like "Koala RestAPI"
    it_should_behave_like "Koala RestAPI with an access token"

    it_should_behave_like "Koala GraphAPI"
    it_should_behave_like "Koala GraphAPI with an access token"
    it_should_behave_like "Koala GraphAPI with GraphCollection"
  end

  describe "without an access token" do
    before(:each) do
      @api = Koala::Facebook::API.new
    end

    it_should_behave_like "Koala RestAPI"
    it_should_behave_like "Koala RestAPI without an access token"

    it_should_behave_like "Koala GraphAPI"
    it_should_behave_like "Koala GraphAPI without an access token"
    it_should_behave_like "Koala GraphAPI with GraphCollection"
  end

  context '#api' do
    let(:access_token) { 'access_token' }
    let(:api) { Koala::Facebook::API.new(access_token) }
    let(:path) { '/path' }
    let(:appsecret) { 'appsecret' }
    let(:token_args) { { 'access_token' => access_token } }
    let(:appsecret_proof_args) { { 'appsecret_proof' => OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), appsecret, access_token) } }
    let(:verb) { 'get' }
    let(:response) { Koala::HTTPService::Response.new(200, '', '') }

    describe "with the :appsecret_proof option set" do

      describe "and with an access token present" do
        describe "and with an appsecret present" do
          let(:api) { Koala::Facebook::API.new(access_token, appsecret) }

          it "should send the appsecret_proof argument" do
            Koala.should_receive(:make_request).with(path, token_args.merge(appsecret_proof_args), verb, {}).and_return(response)

            api.api(path, {}, verb, :appsecret_proof => true)
          end
        end

        describe "but without an appsecret present" do
          it "should not send the appsecret_proof argument" do
            Koala.should_receive(:make_request).with(path, token_args, verb, {}).and_return(response)

            api.api(path, {}, verb, :appsecret_proof => true)
          end
        end
      end

      describe "but without an access token present" do
        describe "and with an appsecret present" do
          let(:api) { Koala::Facebook::API.new(nil, appsecret) }

          it "should not send the appsecret_proof argument" do
            Koala.should_receive(:make_request).with(path, {}, verb, {}).and_return(response)

            api.api(path, {}, verb, :appsecret_proof => true)
          end
        end

        describe "but without an appsecret present" do
          let(:api) { Koala::Facebook::API.new }

          it "should not sent the appsecret_proof argument" do
            Koala.should_receive(:make_request).with(path, {}, verb, {}).and_return(response)

            api.api(path, {}, verb, :appsecret_proof => true)
          end
        end
      end

    end

    describe "without the appsecret_proof option set" do

      describe "and with an access token present" do
        describe "and with an appsecret present" do
          let(:api) { Koala::Facebook::API.new(access_token, appsecret) }

          it "should not send the appsecret_proof argument" do
            Koala.should_receive(:make_request).twice.with(path, token_args, verb, {}).and_return(response)

            api.api(path, {}, verb, :appsecret_proof => false)
            api.api(path)
          end
        end

        describe "but without an appsecret present" do
           it "should not send the appsecret_proof argument" do
             Koala.should_receive(:make_request).twice.with(path, token_args, verb, {}).and_return(response)

             api.api(path, {}, verb, :appsecret_proof => false)
             api.api(path)
           end
        end
      end

      describe "but without an access token present" do
        describe "and with an appsecret present" do
          let(:api) { Koala::Facebook::API.new(nil, appsecret) }

          it "should not send the appsecret_proof argument" do
            Koala.should_receive(:make_request).twice.with(path, {}, verb, {}).and_return(response)

            api.api(path, {}, verb, :appsecret_proof => false)
            api.api(path)
          end
        end

        describe "but without an appsecret present" do
          let(:api) { Koala::Facebook::API.new }

          it "should not send the appsecret_proof argument" do
            Koala.should_receive(:make_request).twice.with(path, {}, verb, {}).and_return(response)

            api.api(path, {}, verb, :appsecret_proof => false)
            api.api(path)
          end
        end
      end
    end
  end
end
