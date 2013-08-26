require 'spec_helper'

describe Stasher::LogSubscriber do
  let(:logger) { MockLogger.new }
  
  before :each do
    Stasher.logger = logger
    Stasher.stub(:source).and_return("source")
    LogStash::Time.stub(:now => 'timestamp')
  end

  subject(:subscriber) { Stasher::LogSubscriber.new }

  describe '#start_processing' do
    let(:payload) { FactoryGirl.create(:actioncontroller_payload) }

    let(:event) {
      ActiveSupport::Notifications::Event.new(
        'process_action.action_controller', Time.now, Time.now, 2, payload
      )
    }

    let(:json) { 
      '{"@source":"source","@tags":["request"],"@fields":{"method":"GET","ip":"127.0.0.1","params":{"foo":"bar"},' +
      '"path":"/home","format":"application/json","controller":"home","action":"index"},"@timestamp":"timestamp"}' + "\n" 
    }

    it 'calls all extractors and outputs the json' do
      subscriber.should_receive(:extract_request).with(payload).and_return({:request => true})
      subscriber.should_receive(:extract_current_scope).with(no_args).and_return({:custom => true})
      subscriber.start_processing(event)
    end

    it "logs the event" do
      subscriber.start_processing(event)

      logger.messages.first.should == json
    end
  end

  describe '#sql' do
    let(:event) {
      ActiveSupport::Notifications::Event.new(
        'sql.active_record', Time.now, Time.now, 2, payload
      )
    }

    context "for SCHEMA events" do
      let(:payload) { FactoryGirl.create(:activerecord_sql_payload, name: 'SCHEMA') }

      it "does not log anything" do
        subscriber.sql(event)

        logger.messages.should be_empty
      end
    end

    context "for unnamed events" do
      let(:payload) { FactoryGirl.create(:activerecord_sql_payload, name: '') }

      it "does not log anything" do
        subscriber.sql(event)

        logger.messages.should be_empty
      end
    end

    context "for session events" do
      let(:payload) { FactoryGirl.create(:activerecord_sql_payload, name: 'ActiveRecord::SessionStore') }

      it "does not log anything" do
        subscriber.sql(event)

        logger.messages.should be_empty
      end
    end

    context "for any other events" do
      let(:payload) { FactoryGirl.create(:activerecord_sql_payload) }

      let(:json) { 
        '{"@source":"source","@tags":["sql"],"@fields":{"name":"User Load","sql":"' + 
        payload[:sql] + '","duration":0.0},"@timestamp":"timestamp"}' + "\n" 
      }

      it 'calls all extractors and outputs the json' do
        subscriber.should_receive(:extract_sql).with(payload).and_return({:sql => true})
        subscriber.should_receive(:extract_current_scope).with(no_args).and_return({:custom => true})
        subscriber.sql(event)
      end

      it "logs the event" do
        subscriber.sql(event)

        logger.messages.first.should == json
      end
    end
  end

  describe '#process_action' do
    let(:payload) { FactoryGirl.create(:actioncontroller_payload) }

    let(:event) {
      ActiveSupport::Notifications::Event.new(
        'process_action.action_controller', Time.now, Time.now, 2, payload
      )
    }

    let(:json) { 
      '{"@source":"source","@tags":["response"],"@fields":{"method":"GET","ip":"127.0.0.1","params":{"foo":"bar"},' +
      '"path":"/home","format":"application/json","controller":"home","action":"index","status":200,' + 
      '"duration":0.0,"view":0.01,"db":0.02},"@timestamp":"timestamp"}' + "\n" 
    }

    it 'calls all extractors and outputs the json' do
      subscriber.should_receive(:extract_request).with(payload).and_return({:request => true})
      subscriber.should_receive(:extract_status).with(payload).and_return({:status => true})
      subscriber.should_receive(:runtimes).with(event).and_return({:runtimes => true})
      subscriber.should_receive(:extract_exception).with(payload).and_return({:exception => true})
      subscriber.should_receive(:extract_current_scope).with(no_args).and_return({:custom => true})
      subscriber.process_action(event)
    end

    it "logs the event" do
      subscriber.process_action(event)

      logger.messages.first.should == json
    end

    context "when the payload includes an exception" do
      before :each do
        payload[:exception] = [ 'Exception', 'message' ]
        subscriber.stub(:extract_exception).and_return({})        
      end

      it "adds the 'exception' tag" do
        subscriber.process_action(event)

        logger.messages.first.should match %r|"@tags":\["response","exception"\]|
      end
    end

    it "clears the scoped parameters" do
      Stasher::CurrentScope.should_receive(:clear!)

      subscriber.process_action(event)
    end

    context "with a redirect" do
      before do
        Stasher::CurrentScope.fields[:location] = "http://www.example.com"
      end

      it "adds the location to the log line" do
        subscriber.process_action(event)
        logger.messages.first.should match %r|"@fields":{.*?"location":"http://www\.example\.com".*?}|
      end
    end
  end

  describe '#log_event' do
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

    context "with a block" do
      it "calls the block with the new event" do
        yielded = []
        subscriber.send :log_event, 'tag', {} do |args|
          yielded << args
        end

        yielded.size.should == 1
        yielded.first.should be_a(LogStash::Event)
      end

      it "logs the modified event" do
        subscriber.send :log_event, 'tag', {} do |event|
          event.tags << "extra"
        end

        logger.messages.first.should match %r|"@tags":\["tag","extra"\]|
      end
    end
  end

  describe '#redirect_to' do
    let(:event) {
      ActiveSupport::Notifications::Event.new(
        'redirect_to.action_controller', Time.now, Time.now, 1, :location => 'http://example.com', :status => 302
      )
    }

    it "stores the payload location in the current scope" do     
      subscriber.redirect_to(event)

      Stasher::CurrentScope.fields[:location].should == "http://example.com"
    end
  end
end