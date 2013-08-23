require 'spec_helper'

describe Stasher::RequestLogSubscriber do
  let(:log_output) {StringIO.new}
  let(:logger) { MockLogger.new }
  
  before :each do
    Stasher.logger = logger
  end

  subject(:subscriber) { Stasher::RequestLogSubscriber.new }
  
  let(:payload) { 
    {
      status: 200, format: 'application/json', method: 'GET', path: '/home?foo=bar', params: {
        :controller => 'home', :action => 'index', 'foo' => 'bar'
      }.with_indifferent_access, db_runtime: 0.02, view_runtime: 0.01
    }
  }

  let(:event) {
    ActiveSupport::Notifications::Event.new(
      'process_action.action_controller', Time.now, Time.now, 2, payload
    )
  }

  let(:redirect) {
    ActiveSupport::Notifications::Event.new(
      'redirect_to.action_controller', Time.now, Time.now, 1, location: 'http://example.com', status: 302
    )
  }

  describe '#process_action' do
    let(:json)    { 
      '{"@source":"source","@tags":["response"],"@fields":{"method":"GET","ip":null,"params":{"foo":"bar"},' +
      '"path":"/home","format":"application/json","controller":"home","action":"index","status":200,' + 
      '"duration":0.0,"view":0.01,"db":0.02},"@timestamp":"timestamp"}' + "\n" 
    }

    before :each do
      Stasher.stub(:source).and_return("source")
      LogStash::Time.stub(:now => 'timestamp')
    end

    it 'calls all extractors and outputs the json' do
      subscriber.should_receive(:extract_request).with(payload).and_return({:request => true})
      subscriber.should_receive(:extract_status).with(payload).and_return({:status => true})
      subscriber.should_receive(:runtimes).with(event).and_return({:runtimes => true})
      subscriber.should_receive(:location).with(event).and_return({:location => true})
      subscriber.should_receive(:extract_exception).with(payload).and_return({:exception => true})
      subscriber.should_receive(:extract_current_scope).with(no_args).and_return({:custom => true})
      subscriber.process_action(event)
    end

    it "logs the event" do
      subscriber.process_action(event)

      logger.messages.first.should == json
    end
  end

  describe '#log_event' do
    before :each do
      Stasher.stub(:source).and_return("source")
    end

    it "sets the type as a @tag" do
      subscriber.send :log_event, 'tag', {}

      logger.messages.first.should match %r|"@tags":\["tag"\]|
    end

    it "renders the data in the @fields" do
      subscriber.send :log_event, 'tag', { "foo" => "bar", :baz => 'bot' }

      logger.messages.first.should match %r|"@fields":{"foo":"bar","baz":"bot"}|
    end

    it "sets the @source" do
      subscriber.send :log_event, 'tag', {}

      logger.messages.first.should match %r|"@source":"source"|
    end
  end
=begin
  describe "old" do
    it "should contain request tag" do
      subscriber.process_action(event)
      log_output.json['@tags'].should include 'request'
    end

    it "should contain HTTP method" do
      subscriber.process_action(event)
      log_output.json['@fields']['method'].should == 'GET'
    end

    it "should include the path in the log output" do
      subscriber.process_action(event)
      log_output.json['@fields']['path'].should == '/home'
    end

    it "should include the format in the log output" do
      subscriber.process_action(event)
      log_output.json['@fields']['format'].should == 'application/json'
    end

    it "should include the status code" do
      subscriber.process_action(event)
      log_output.json['@fields']['status'].should == 200
    end

    it "should include the controller" do
      subscriber.process_action(event)
      log_output.json['@fields']['controller'].should == 'home'
    end

    it "should include the action" do
      subscriber.process_action(event)
      log_output.json['@fields']['action'].should == 'index'
    end

    it "should include the view rendering time" do
      subscriber.process_action(event)
      log_output.json['@fields']['view'].should == 0.01
    end

    it "should include the database rendering time" do
      subscriber.process_action(event)
      log_output.json['@fields']['db'].should == 0.02
    end

    it "should add a 500 status when an exception occurred" do
      begin
        raise AbstractController::ActionNotFound.new('Could not find an action')
      # working this in rescue to get access to $! variable
      rescue
        event.payload[:status] = nil
        event.payload[:exception] = ['AbstractController::ActionNotFound', 'Route not found']
        subscriber.process_action(event)
        log_output.json['@fields']['status'].should == 500
        log_output.json['@fields']['error'].should =~ /AbstractController::ActionNotFound.*Route not found.*logstasher\/spec\/logstasher_logsubscriber_spec\.rb/m
        log_output.json['@tags'].should include 'request'
        log_output.json['@tags'].should include 'exception'
      end
    end

    it "should return an unknown status when no status or exception is found" do
      event.payload[:status] = nil
      event.payload[:exception] = nil
      subscriber.process_action(event)
      log_output.json['@fields']['status'].should == 0
    end

    describe "with a redirect" do
      before do
        Thread.current[:logstasher_location] = "http://www.example.com"
      end

      it "should add the location to the log line" do
        subscriber.process_action(event)
        log_output.json['@fields']['location'].should == 'http://www.example.com'
      end

      it "should remove the thread local variable" do
        subscriber.process_action(event)
        Thread.current[:logstasher_location].should == nil
      end
    end

    it "should not include a location by default" do
      subscriber.process_action(event)
      log_output.json['@fields']['location'].should be_nil
    end
  end

  describe "with append_custom_params block specified" do
    let(:request) { mock(:remote_ip => '10.0.0.1')}
    it "should add default custom data to the output" do
      request.stub(:params => event.payload[:params])
      Stasher.add_default_fields_to_payload(event.payload, request)
      subscriber.process_action(event)
      log_output.json['@fields']['ip'].should == '10.0.0.1'
      log_output.json['@fields']['route'].should == 'home#index'
      log_output.json['@fields']['parameters'].should == "foo=bar\n"
    end
  end

  describe "with append_custom_params block specified" do
    before do
      Stasher.stub(:add_custom_fields) do |&block|
        @block = block
      end
      Stasher.add_custom_fields do |payload|
        payload[:user] = 'user'
      end
      Stasher.custom_fields += [:user]
    end

    it "should add the custom data to the output" do
      @block.call(event.payload)
      subscriber.process_action(event)
      log_output.json['@fields']['user'].should == 'user'
    end
  end

  describe "when processing a redirect" do
    it "should store the location in a thread local variable" do
      subscriber.redirect_to(redirect)
      Thread.current[:logstasher_location].should == "http://example.com"
    end
  end
=end
end