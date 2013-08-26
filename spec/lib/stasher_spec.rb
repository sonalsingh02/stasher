require 'spec_helper'

describe Stasher do
  describe "when removing Rails' log subscribers" do
    after do
      ActionController::LogSubscriber.attach_to :action_controller
      ActionView::LogSubscriber.attach_to :action_view
    end

    it "should remove subscribers for controller events" do
      expect {
        Stasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      }
    end

    it "should remove subscribers for all events" do
      expect {
        Stasher.remove_existing_log_subscriptions
      }.to change {
        ActiveSupport::Notifications.notifier.listeners_for('render_template.action_view')
      }
    end

    it "shouldn't remove subscribers that aren't from Rails" do
      blk = -> {}
      ActiveSupport::Notifications.subscribe("process_action.action_controller", &blk)
      Stasher.remove_existing_log_subscriptions
      listeners = ActiveSupport::Notifications.notifier.listeners_for('process_action.action_controller')
      listeners.size.should > 0
    end
  end

  describe '.add_default_fields_to_scope' do
    let(:scope) { {} }
    let(:request) { double(:params => {}, :remote_ip => '10.0.0.1', :uuid => "uuid" )}
    
    it 'appends default parameters to payload' do
      Stasher.add_default_fields_to_scope(scope, request)
      
      scope.should == { :uuid => "uuid" }
    end
  end

  describe '.add_custom_fields' do
    let(:block) { ->{} }

    it 'defines a method in ActionController::Metal' do
      ActionController::Metal.should_receive(:send).with(:define_method, :stasher_add_custom_fields_to_scope, &block)
      Stasher.add_custom_fields(&block)
    end
  end

  describe '.setup' do
    let(:logger) { double }
    let(:stasher_config) { double(:logger => logger, :attach_to => [:active_record], :log_level => nil, :suppress_app_log => nil ) }
    let(:config) { double(:stasher => stasher_config) }
    let(:app) { double(:config => config) }
    
    before :each do
      logger.stub(:level=)
      config.stub(:action_dispatch => double(:rack_cache => false))
    end

    context "when suppress_app_log is true" do
      before :each do
        stasher_config.stub(:suppress_app_log).and_return(true)
      end

      it 'suppresses the default logger' do
        Stasher.should_receive(:suppress_app_logs).with(app)
        Stasher.setup(app)
      end
    end

    context "when suppress_app_log is false" do
      before :each do
        stasher_config.stub(:suppress_app_log).and_return(false)
      end

      it 'does not suppress the default logger' do
        Stasher.should_not_receive(:suppress_app_logs).with(app)

        Stasher.setup(app)
      end
    end

    it "attaches to the requested notifiers" do
      Stasher::LogSubscriber.should_receive(:attach_to).with(:active_record)
  
      Stasher.setup(app)
    end

    context "when a log level is configured" do
      before :each do
        stasher_config.stub(:log_level).and_return(:debug)
      end

      it "sets the configured log level" do
        logger.should_receive(:level=).with(::Logger::DEBUG)

        Stasher.setup(app)
      end
    end

    context "when a log level is not configured" do
      it "defaults to WARN" do
        logger.should_receive(:level=).with(::Logger::WARN)

        Stasher.setup(app)
      end
    end

    it "sets itself as enabled" do
      Stasher.setup(app)
      Stasher.enabled.should be_true
    end

    it "sets its source" do
      Stasher.stub(:hostname).and_return('hostname')

      Stasher.setup(app)
      Stasher.source.should == "rails://hostname/r_spec/mocks"
    end    
  end

  describe '.suppress_app_logs' do
    let(:stasher_config){ double(:stasher => double.as_null_object).as_null_object }
    let(:app){ double(:config => stasher_config)}

    it 'removes existing subscriptions' do
      Stasher.should_receive(:require).with('stasher/rails_ext/rack/logger')
      Stasher.should_receive(:remove_existing_log_subscriptions)
      Stasher.suppress_app_logs(app)
    end
  end

  describe '.format_exception' do
    let(:type_name) { 'type' }
    let(:message) { 'message' }
    let(:backtrace) { 'backtrace' }

    it "returns a hash of exception details" do
      Stasher.format_exception(type_name, message, backtrace).should == {
        :exception => {
          :name => type_name,
          :message => message,
          :backtrace => backtrace
        }
      }
    end
  end

  describe '.log' do
    let(:logger) { MockLogger.new }
    
    before :each do
      Stasher.logger = logger
      Stasher.source = "source"
      LogStash::Time.stub(:now => 'timestamp')
    end

    it 'ensures the log is configured to log at the given level' do
      logger.should_receive(:send).with('warn?').and_return(true)
      Stasher.log('warn', 'WARNING')
    end

    it "does not log if the log level is higher than the severity" do      
      expect {
        Stasher.log('debug', 'DEBUG')        
      }.not_to change{logger.messages.size}
    end

    it 'adds to log with specified level' do     
      Stasher.log('warn', 'WARNING')

      logger.messages.first.should include '"@fields":{"severity":"WARN"}'
    end

    it "adds the 'log' tag" do
      Stasher.log('warn', 'WARNING')
      logger.messages.first.should match %r|"@tags":\[[^\[]*"log"[^\]]*\]|
    end

    it "adds a tag indicating the severity" do
      Stasher.log('warn', 'WARNING')
      logger.messages.first.should match %r|"@tags":\[[^\[]*"warn"[^\]]*\]|
    end

    it "logs the message to @message" do
      Stasher.log('warn', "MESSAGE")
      logger.messages.first.should include '"@message":"MESSAGE"'
    end

    it "logs the source to @source" do
      Stasher.log('warn', "MESSAGE")
      logger.messages.first.should include '"@source":"source"'
    end

    it "strips out ANSI color sequences" do
      Stasher.log('warn', "\e[7;1mHELLO\e[0m WORLD")
      logger.messages.first.should include '"@message":"HELLO WORLD"'
    end

    context "with fields in the current scope" do      
      before :each do
        Stasher::CurrentScope.fields = { :field => "value" }
      end

      it 'includes the current scope fields' do
        Stasher.log('warn', 'WARNING')
        
        logger.messages.first.should match %r|"@fields":{[^}]*"field":"value"[^}]*}|
      end
    end

    context "when logging an Exception" do
      let(:exception) { Exception.new("Message") }

      before :each do
        exception.set_backtrace ["first", "second"]
      end

      it "logs the exception details" do
        Stasher.log('error', exception)
        logger.messages.first.should match %r|"exception":{"name":"Exception","message":"Message","backtrace":"first\\nsecond"}|
      end

      it "adds the 'exception' tag" do
        Stasher.log('error', exception)
        logger.messages.first.should match %r|\"@tags\":\[[^\[]*\"exception\"[^\]]*\]|
      end
    end
  end

  %w( fatal error warn info debug unknown ).each do |severity|
    describe ".#{severity}" do
      let(:message) { "This is a #{severity} message" }
      it 'should log with specified level' do
        Stasher.should_receive(:log).with(severity.to_sym, message)
        Stasher.send(severity, message )
      end
    end
  end
end